#!/usr/bin/env python3
"""Package BlastShield for release distributions."""

import hashlib
import os
import re
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DIST_DIR = REPO_ROOT / "dist"
DIST_DIR.mkdir(exist_ok=True)


def get_version() -> str:
    version_line = next(
        line for line in (REPO_ROOT / "blastshield").read_text().splitlines()
        if line.startswith("readonly VERSION=")
    )
    match = re.search(r'readonly VERSION="([^"]+)"', version_line)
    if not match:
        raise ValueError("Could not parse VERSION from blastshield script")
    return match.group(1)


def compute_sha256(filepath: Path) -> str:
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(8192):
            h.update(chunk)
    return h.hexdigest()


def package() -> Path:
    version = get_version()
    safe_version = version.lstrip("v")
    base_name = f"blastshield-{safe_version}"
    tmpdir = REPO_ROOT / ".releases" / base_name
    if tmpdir.exists():
        subprocess.run(["rm", "-rf", str(tmpdir)], check=True)
    tmpdir.mkdir(parents=True)

    for filename in ["blastshield", "README.md", "LICENSE"]:
        src_file = REPO_ROOT / filename
        if src_file.exists():
            (tmpdir / filename).write_bytes(src_file.read_bytes())

    for src_dir_name in ["profiles", "helpers", "completions"]:
        src_dir = REPO_ROOT / src_dir_name
        if src_dir.exists():
            dst_dir = tmpdir / src_dir_name
            dst_dir.mkdir()
            for f in src_dir.iterdir():
                if f.name.startswith("."):
                    continue
                (dst_dir / f.name).write_bytes(f.read_bytes())
                if src_dir_name == "helpers" and f.name == "blastshield-guard":
                    (dst_dir / f.name).chmod(0o755)

    (tmpdir / "blastshield").chmod(0o755)

    tarball = DIST_DIR / f"{base_name}.tar.gz"
    subprocess.run(
        ["tar", "-czf", str(tarball), "-C", str(REPO_ROOT / ".releases"), base_name],
        check=True,
    )
    return tarball


def main() -> None:
    tarball = package()
    checksum = compute_sha256(tarball)
    checksum_file = DIST_DIR / "checksums.txt"
    with open(checksum_file, "a") as f:
        f.write(f"{checksum}  {tarball.name}\n")
    print(f"Package: {tarball}")
    print(f"SHA256:  {checksum}")

if __name__ == "__main__":
    main()
