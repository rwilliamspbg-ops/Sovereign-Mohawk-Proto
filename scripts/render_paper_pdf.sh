#!/usr/bin/env bash
# render_paper_pdf.sh -- regenerate docs/ACADEMIC_PAPER.pdf from the Markdown source.
#
# Toolchain: pandoc (Markdown -> Typst/PDF) + the Typst CLI as the PDF engine.
# Typst is used instead of a LaTeX distribution because it renders the paper's
# $...$ mathematics natively while being a ~50 MB single binary rather than a
# multi-GB TeX install.
#
# Install on Windows with winget:
#   winget install --id JohnMacFarlane.Pandoc -e
#   winget install --id Typst.Typst -e
# On Linux/macOS: install pandoc and typst from your package manager.
#
# Usage:
#   bash scripts/render_paper_pdf.sh                 # docs/ACADEMIC_PAPER.pdf
#   bash scripts/render_paper_pdf.sh --check         # fail if the PDF is stale
#
# Exit code is non-zero if a tool is missing or the render fails.

set -euo pipefail

# to_win converts an MSYS path (/c/Users/...) to a native Windows path
# (C:\Users\...). Native tools (pandoc, typst) cannot open MSYS paths.
to_win() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s\n' "$1"; fi
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$REPO_ROOT/docs/ACADEMIC_PAPER.md"
TARGET="$REPO_ROOT/docs/ACADEMIC_PAPER.pdf"

CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

find_pandoc() {
  if command -v pandoc >/dev/null 2>&1; then command -v pandoc; return; fi
  # winget's per-user Pandoc install on Windows
  for p in "$LOCALAPPDATA/Pandoc/pandoc.exe" "$HOME/AppData/Local/Pandoc/pandoc.exe"; do
    [ -x "$p" ] && { printf '%s\n' "$p"; return; }
  done
  return 1
}

find_typst() {
  if command -v typst >/dev/null 2>&1; then command -v typst; return; fi
  # winget's per-user Typst install on Windows
  local hits
  hits=$(ls -d "$LOCALAPPDATA"/Microsoft/WinGet/Packages/Typst.Typst_*/typst-x86_64-pc-windows-msvc/typst.exe 2>/dev/null \
         "$HOME"/AppData/Local/Microsoft/WinGet/Packages/Typst.Typst_*/typst-x86_64-pc-windows-msvc/typst.exe 2>/dev/null || true)
  if [ -n "$hits" ]; then printf '%s\n' $hits | head -1; return; fi
  return 1
}

if [ "$CHECK_ONLY" = 1 ]; then
  # A stale check compares mtimes, not bytes: the PDF embeds a creation
  # timestamp, so byte comparison would always differ.
  if [ ! -f "$TARGET" ]; then
    echo "[paper] MISSING: $TARGET" >&2
    exit 1
  fi
  if [ "$SOURCE" -nt "$TARGET" ]; then
    echo "[paper] STALE: $SOURCE is newer than $TARGET" >&2
    echo "        regenerate with: bash scripts/render_paper_pdf.sh" >&2
    exit 1
  fi
  echo "[paper] PDF is up to date: $TARGET"
  exit 0
fi

PANDOC=$(find_pandoc) || { echo "[paper] pandoc not found. Install it:" >&2
  echo "        winget install --id JohnMacFarlane.Pandoc -e" >&2
  echo "        # or your platform package manager" >&2; exit 1; }
TYPST=$(find_typst) || { echo "[paper] typst not found. Install it:" >&2
  echo "        winget install --id Typst.Typst -e" >&2
  echo "        # or your platform package manager" >&2; exit 1; }

echo "[paper] pandoc: $PANDOC"
echo "[paper] typst:  $TYPST"
echo "[paper] source: $SOURCE"
echo "[paper] target: $TARGET"

"$PANDOC" "$(to_win "$SOURCE")" -o "$(to_win "$TARGET")" --pdf-engine="$(to_win "$TYPST")"

echo "[paper] wrote $TARGET ($(wc -c < "$TARGET") bytes)"
