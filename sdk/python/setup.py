"""Setup script for the Sovereign-Mohawk Python SDK."""

import subprocess
import sys
from pathlib import Path

from setuptools import find_packages, setup
from setuptools.command.build_ext import build_ext


class BuildGoLibrary(build_ext):
    """Custom build command to compile the Go shared library."""

    def run(self):
        """Build the Go C-shared library."""
        print("🏗️  Building MOHAWK Go shared library...")

        # Navigate to repository root (3 levels up from sdk/python/)
        repo_root = Path(__file__).parent.parent.parent
        go_api_path = repo_root / "internal" / "pyapi" / "api.go"

        if not go_api_path.exists():
            raise RuntimeError(f"Go API file not found: {go_api_path}")

        # Determine shared library extension based on platform
        if sys.platform == "darwin":
            lib_name = "libmohawk.dylib"
        elif sys.platform.startswith("linux"):
            lib_name = "libmohawk.so"
        elif sys.platform == "win32":
            lib_name = "libmohawk.dll"
        else:
            raise RuntimeError(f"Unsupported platform: {sys.platform}")

        output_path = repo_root / lib_name

        # Build command
        cmd = [
            "go",
            "build",
            "-o",
            str(output_path),
            "-buildmode=c-shared",
            str(go_api_path),
        ]

        print(f"Running: {' '.join(cmd)}")

        try:
            subprocess.run(
                cmd, cwd=str(repo_root), check=True, capture_output=True, text=True
            )
            print(f"✅ Successfully built {lib_name}")
        except subprocess.CalledProcessError as e:
            print(f"❌ Build failed:\n{e.stderr}", file=sys.stderr)
            raise RuntimeError(f"Failed to build Go library: {e}")

        # Continue with regular extension building
        super().run()


with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="sovereign-mohawk",
    version="2.0.0a1",
    author="rwilliamspbg-ops",
    description="Python SDK for Sovereign-Mohawk federated learning protocol",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
        "License :: OSI Approved :: Apache Software License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
    python_requires=">=3.8",
    install_requires=[
        # No external Python dependencies required
    ],
    extras_require={
        "dev": [
            "pytest>=7.0",
            "pytest-cov>=4.0",
            "black>=23.0",
            "mypy>=1.0",
            "ruff>=0.1.0",
        ],
    },
    cmdclass={
        "build_ext": BuildGoLibrary,
    },
    include_package_data=True,
    package_data={
        "mohawk": ["*.so", "*.dylib", "*.dll"],
    },
)
