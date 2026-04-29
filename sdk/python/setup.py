import re
import subprocess
import sys
from pathlib import Path

from setuptools import find_packages, setup  # type: ignore[import-untyped]
from setuptools.command.build_py import build_py  # type: ignore[import-untyped]

PACKAGE_NAME = "mohawk"
PACKAGE_DIR = Path(__file__).resolve().parent / PACKAGE_NAME
REPO_ROOT = Path(__file__).resolve().parents[2]
GO_API_PATH = REPO_ROOT / "internal" / "pyapi" / "api.go"


def _package_version() -> str:
    init_text = (PACKAGE_DIR / "__init__.py").read_text(encoding="utf-8")
    match = re.search(r'^__version__ = "([^"]+)"', init_text, re.MULTILINE)
    if match is None:
        raise RuntimeError("Unable to determine package version from mohawk/__init__.py")
    return match.group(1)


def _shared_library_name() -> str:
    if sys.platform == "darwin":
        return "libmohawk.dylib"
    if sys.platform.startswith("linux"):
        return "libmohawk.so"
    if sys.platform == "win32":
        return "libmohawk.dll"
    raise RuntimeError(f"Unsupported platform: {sys.platform}")


def _build_go_library(output_dir: Path) -> Path:
    if not GO_API_PATH.exists():
        raise RuntimeError(f"Go API file not found: {GO_API_PATH}")

    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / _shared_library_name()
    cmd = [
        "go",
        "build",
        "-o",
        str(output_path),
        "-buildmode=c-shared",
        str(GO_API_PATH),
    ]
    print(f"Running: {' '.join(cmd)}")
    try:
        subprocess.run(cmd, cwd=str(REPO_ROOT), check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as exc:
        print(f"Build failed:\n{exc.stderr}", file=sys.stderr)
        raise RuntimeError(f"Failed to build Go library: {exc}") from exc
    return output_path


class BuildGoLibrary(build_py):
    """Compile the Go shared library into the built Python package."""

    def run(self):
        package_build_dir = Path(self.build_lib) / PACKAGE_NAME
        print("Building MOHAWK Go shared library...")
        built_library = _build_go_library(package_build_dir)
        print(f"Built shared library: {built_library}")
        super().run()


setup(
    version=_package_version(),
    packages=find_packages(),
    cmdclass={
        "build_py": BuildGoLibrary,
    },
    package_data={
        PACKAGE_NAME: ["*.so", "*.dylib", "*.dll"],
    },
)
