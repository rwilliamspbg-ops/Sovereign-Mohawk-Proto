#!/usr/bin/env python3
"""Train a simple binary classifier on a synthesize.bio dataset export.

This script supports two input modes:
1) Local CSV export path (--input-csv)
2) synthesize.bio dataset URL/ID with optional bearer token

For synthesize.bio URLs/IDs, authentication may be required to retrieve the
dataset payload or download URL.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import random
import re
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

DATASET_ID_RE = re.compile(
    r"(?P<id>[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"
)


@dataclass
class DatasetTable:
    headers: list[str]
    rows: list[list[str]]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Train on a synthesize.bio dataset export"
    )
    parser.add_argument(
        "dataset",
        nargs="?",
        help="Dataset URL or dataset UUID (ignored if --input-csv is provided)",
    )
    parser.add_argument(
        "--input-csv",
        default="",
        help="Path to a local CSV export of the synthesize.bio dataset",
    )
    parser.add_argument(
        "--label-column",
        default="",
        help="Label column name; defaults to first binary-like column",
    )
    parser.add_argument(
        "--token",
        default=os.getenv("SYNTHESIZE_BIO_TOKEN", ""),
        help="Bearer token for synthesize.bio API (or set SYNTHESIZE_BIO_TOKEN)",
    )
    parser.add_argument(
        "--epochs",
        type=int,
        default=200,
        help="Training epochs for logistic regression",
    )
    parser.add_argument(
        "--lr",
        type=float,
        default=0.05,
        help="Learning rate",
    )
    parser.add_argument(
        "--test-split",
        type=float,
        default=0.2,
        help="Fraction of records reserved for test set",
    )
    parser.add_argument(
        "--output",
        default="results/demo/synthesize_bio/training_report.json",
        help="Path for JSON training report",
    )
    return parser.parse_args()


def _http_get(url: str, token: str = "") -> tuple[int, bytes, dict[str, str]]:
    req = urllib.request.Request(url)
    req.add_header("Accept", "application/json, text/csv;q=0.9, */*;q=0.8")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.getcode(), resp.read(), dict(resp.headers.items())


def extract_dataset_id(raw: str) -> str:
    match = DATASET_ID_RE.search(raw)
    if not match:
        raise ValueError("Could not parse dataset UUID from input")
    return match.group("id")


def load_csv_file(path: Path) -> DatasetTable:
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.reader(f)
        headers = next(reader, None)
        if not headers:
            raise ValueError(f"CSV has no header: {path}")
        rows = [row for row in reader if row]
    return DatasetTable(headers=headers, rows=rows)


def parse_csv_bytes(payload: bytes) -> DatasetTable:
    text = payload.decode("utf-8", errors="replace")
    reader = csv.reader(text.splitlines())
    headers = next(reader, None)
    if not headers:
        raise ValueError("CSV payload has no header")
    rows = [row for row in reader if row]
    return DatasetTable(headers=headers, rows=rows)


def load_from_synthesize(dataset_id: str, token: str) -> DatasetTable:
    # Try direct export endpoints first, then metadata endpoint for download URL.
    direct_candidates = [
        f"https://app.synthesize.bio/api/datasets/{dataset_id}/download",
        f"https://app.synthesize.bio/datasets/{dataset_id}/download",
    ]

    for url in direct_candidates:
        try:
            code, payload, headers = _http_get(url, token=token)
            content_type = headers.get("Content-Type", "")
            if "text/csv" in content_type or payload[:64].lower().startswith(b"id,"):
                return parse_csv_bytes(payload)
            if "application/json" in content_type:
                body = json.loads(payload.decode("utf-8", errors="replace"))
                dl = body.get("download_url") or body.get("url")
                if isinstance(dl, str) and dl:
                    _, csv_payload, _ = _http_get(dl, token="")
                    return parse_csv_bytes(csv_payload)
            if code == 200 and payload.lstrip().startswith(b"<"):
                continue
        except urllib.error.HTTPError as exc:
            if exc.code in (401, 403):
                raise PermissionError(
                    "Dataset access requires authentication. Set SYNTHESIZE_BIO_TOKEN or use --input-csv."
                ) from exc
            if exc.code == 404:
                continue
            raise

    # Metadata fallback.
    metadata_candidates = [
        f"https://app.synthesize.bio/api/datasets/{dataset_id}",
        f"https://app.synthesize.bio/api/v1/datasets/{dataset_id}",
    ]
    for url in metadata_candidates:
        try:
            _, payload, _ = _http_get(url, token=token)
            body = json.loads(payload.decode("utf-8", errors="replace"))
            dl = body.get("download_url") or body.get("url")
            if isinstance(dl, str) and dl:
                _, csv_payload, _ = _http_get(dl, token="")
                return parse_csv_bytes(csv_payload)
        except urllib.error.HTTPError as exc:
            if exc.code in (401, 403):
                raise PermissionError(
                    "Dataset metadata access requires authentication. Set SYNTHESIZE_BIO_TOKEN or use --input-csv."
                ) from exc
            if exc.code == 404:
                continue
            raise
        except json.JSONDecodeError:
            continue

    raise RuntimeError(
        "Could not retrieve a CSV export from synthesize.bio for this dataset ID. "
        "Export the dataset as CSV in the web UI and rerun with --input-csv."
    )


def is_float(value: str) -> bool:
    try:
        float(value)
        return True
    except Exception:
        return False


def to_binary(value: str) -> int | None:
    lowered = value.strip().lower()
    if lowered in {"1", "true", "yes", "y", "positive", "pos"}:
        return 1
    if lowered in {"0", "false", "no", "n", "negative", "neg"}:
        return 0
    if is_float(lowered):
        f = float(lowered)
        if f in (0.0, 1.0):
            return int(f)
    return None


def choose_label_column(
    headers: list[str], rows: Iterable[list[str]], requested: str
) -> str:
    if requested:
        if requested not in headers:
            raise ValueError(f"Label column '{requested}' not found in headers")
        return requested

    sample = list(rows)
    for idx, name in enumerate(headers):
        vals = [to_binary(r[idx]) for r in sample if len(r) > idx]
        vals = [v for v in vals if v is not None]
        if len(vals) >= max(10, int(0.6 * len(sample))):
            return name
    raise ValueError(
        "Could not infer binary label column; pass --label-column explicitly"
    )


def vectorize(
    table: DatasetTable, label_col: str
) -> tuple[list[list[float]], list[int], list[str]]:
    label_idx = table.headers.index(label_col)
    feature_idxs = [i for i in range(len(table.headers)) if i != label_idx]

    usable_numeric = []
    for idx in feature_idxs:
        values = [r[idx] for r in table.rows if len(r) > idx]
        numeric_count = sum(1 for v in values if is_float(v))
        if values and numeric_count / len(values) >= 0.95:
            usable_numeric.append(idx)

    if not usable_numeric:
        raise ValueError("No numeric feature columns found for training")

    X: list[list[float]] = []
    y: list[int] = []
    for row in table.rows:
        if max(usable_numeric + [label_idx]) >= len(row):
            continue
        label = to_binary(row[label_idx])
        if label is None:
            continue
        try:
            feats = [float(row[idx]) for idx in usable_numeric]
        except ValueError:
            continue
        X.append(feats)
        y.append(label)

    if len(X) < 50:
        raise ValueError("Too few usable rows (<50) after filtering")

    feature_names = [table.headers[i] for i in usable_numeric]
    return X, y, feature_names


def standardize(
    X: list[list[float]],
) -> tuple[list[list[float]], list[float], list[float]]:
    n = len(X)
    d = len(X[0])
    means = [0.0] * d
    stds = [0.0] * d

    for j in range(d):
        means[j] = sum(X[i][j] for i in range(n)) / n
    for j in range(d):
        var = sum((X[i][j] - means[j]) ** 2 for i in range(n)) / n
        stds[j] = math.sqrt(var) if var > 1e-12 else 1.0

    out = [[(row[j] - means[j]) / stds[j] for j in range(d)] for row in X]
    return out, means, stds


def split_data(X: list[list[float]], y: list[int], test_split: float) -> tuple:
    idxs = list(range(len(X)))
    random.Random(42).shuffle(idxs)
    test_n = max(1, int(len(X) * test_split))
    test_idxs = set(idxs[:test_n])
    X_train, y_train, X_test, y_test = [], [], [], []
    for i in range(len(X)):
        if i in test_idxs:
            X_test.append(X[i])
            y_test.append(y[i])
        else:
            X_train.append(X[i])
            y_train.append(y[i])
    return X_train, y_train, X_test, y_test


def sigmoid(z: float) -> float:
    if z >= 0:
        ez = math.exp(-z)
        return 1.0 / (1.0 + ez)
    ez = math.exp(z)
    return ez / (1.0 + ez)


def train_logreg(
    X: list[list[float]], y: list[int], epochs: int, lr: float
) -> tuple[list[float], float]:
    d = len(X[0])
    w = [0.0] * d
    b = 0.0
    n = len(X)

    for _ in range(epochs):
        grad_w = [0.0] * d
        grad_b = 0.0
        for xi, yi in zip(X, y):
            z = sum(w[j] * xi[j] for j in range(d)) + b
            p = sigmoid(z)
            err = p - yi
            for j in range(d):
                grad_w[j] += err * xi[j]
            grad_b += err

        scale = 1.0 / n
        for j in range(d):
            w[j] -= lr * grad_w[j] * scale
        b -= lr * grad_b * scale
    return w, b


def evaluate(
    X: list[list[float]], y: list[int], w: list[float], b: float
) -> dict[str, float]:
    tp = tn = fp = fn = 0
    losses = []
    for xi, yi in zip(X, y):
        z = sum(w[j] * xi[j] for j in range(len(w))) + b
        p = sigmoid(z)
        losses.append(
            -(yi * math.log(max(p, 1e-8)) + (1 - yi) * math.log(max(1 - p, 1e-8)))
        )
        pred = 1 if p >= 0.5 else 0
        if pred == 1 and yi == 1:
            tp += 1
        elif pred == 0 and yi == 0:
            tn += 1
        elif pred == 1 and yi == 0:
            fp += 1
        else:
            fn += 1

    total = max(1, tp + tn + fp + fn)
    acc = (tp + tn) / total
    precision = tp / max(1, tp + fp)
    recall = tp / max(1, tp + fn)
    f1 = 2 * precision * recall / max(1e-8, precision + recall)
    return {
        "accuracy": acc,
        "precision": precision,
        "recall": recall,
        "f1": f1,
        "log_loss": sum(losses) / max(1, len(losses)),
    }


def main() -> int:
    args = parse_args()

    try:
        if args.input_csv:
            table = load_csv_file(Path(args.input_csv))
            dataset_ref = str(Path(args.input_csv).resolve())
        else:
            if not args.dataset:
                raise ValueError("Provide a dataset URL/UUID or --input-csv")
            dataset_id = extract_dataset_id(args.dataset)
            table = load_from_synthesize(dataset_id, token=args.token)
            dataset_ref = dataset_id

        label_col = choose_label_column(table.headers, table.rows, args.label_column)
        X_raw, y, feature_names = vectorize(table, label_col)
        X_norm, _, _ = standardize(X_raw)
        X_train, y_train, X_test, y_test = split_data(X_norm, y, args.test_split)

        w, b = train_logreg(X_train, y_train, epochs=args.epochs, lr=args.lr)
        train_metrics = evaluate(X_train, y_train, w, b)
        test_metrics = evaluate(X_test, y_test, w, b)

        report = {
            "dataset": dataset_ref,
            "rows_total": len(X_norm),
            "rows_train": len(X_train),
            "rows_test": len(X_test),
            "label_column": label_col,
            "feature_count": len(feature_names),
            "feature_names": feature_names,
            "epochs": args.epochs,
            "learning_rate": args.lr,
            "metrics": {
                "train": train_metrics,
                "test": test_metrics,
            },
        }

        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )

        print("Training complete")
        print(f"Dataset: {dataset_ref}")
        print(f"Rows: {len(X_norm)} (train={len(X_train)}, test={len(X_test)})")
        print(f"Label column: {label_col}")
        print(f"Features: {len(feature_names)}")
        print(
            "Test metrics: "
            f"accuracy={test_metrics['accuracy']:.4f}, "
            f"precision={test_metrics['precision']:.4f}, "
            f"recall={test_metrics['recall']:.4f}, "
            f"f1={test_metrics['f1']:.4f}, "
            f"log_loss={test_metrics['log_loss']:.4f}"
        )
        print(f"Report: {out}")
        return 0
    except PermissionError as exc:
        print(f"AUTHENTICATION REQUIRED: {exc}")
        return 2
    except Exception as exc:
        print(f"ERROR: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
