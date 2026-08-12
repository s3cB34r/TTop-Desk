#!/usr/bin/env python3
"""Create release archives with stable ordering, metadata, and timestamps."""

from __future__ import annotations

import argparse
import gzip
import os
import stat
import tarfile
import zipfile
from pathlib import Path, PurePosixPath


FIXED_ZIP_TIME = (1980, 1, 1, 0, 0, 0)


def source_entries(source: Path) -> list[Path]:
    return sorted(source.rglob("*"), key=lambda path: path.relative_to(source).as_posix())


def normalized_mode(path: Path) -> int:
    if path.is_dir():
        return 0o755
    return 0o755 if os.access(path, os.X_OK) else 0o644


def archive_name(source: Path, path: Path, prefix: str) -> str:
    relative = PurePosixPath(path.relative_to(source).as_posix())
    return (PurePosixPath(prefix) / relative).as_posix() if prefix else relative.as_posix()


def create_zip(source: Path, output: Path, prefix: str) -> None:
    with zipfile.ZipFile(
        output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as archive:
        for path in source_entries(source):
            if path.is_symlink():
                raise SystemExit(f"symbolic links are not allowed in release archives: {path}")
            if path.is_dir():
                continue
            name = archive_name(source, path, prefix)
            info = zipfile.ZipInfo(name, FIXED_ZIP_TIME)
            info.create_system = 3
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (stat.S_IFREG | normalized_mode(path)) << 16
            info.flag_bits |= 0x800
            archive.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def create_tar_gz(source: Path, output: Path, prefix: str) -> None:
    with output.open("wb") as raw_output:
        with gzip.GzipFile(
            filename="", mode="wb", fileobj=raw_output, compresslevel=9, mtime=0
        ) as compressed:
            with tarfile.open(fileobj=compressed, mode="w", format=tarfile.PAX_FORMAT) as archive:
                if prefix:
                    root_info = tarfile.TarInfo(prefix.rstrip("/") + "/")
                    root_info.type = tarfile.DIRTYPE
                    root_info.mode = 0o755
                    root_info.uid = root_info.gid = 0
                    root_info.uname = root_info.gname = "root"
                    root_info.mtime = 0
                    archive.addfile(root_info)
                for path in source_entries(source):
                    if path.is_symlink():
                        raise SystemExit(
                            f"symbolic links are not allowed in release archives: {path}"
                        )
                    name = archive_name(source, path, prefix)
                    info = tarfile.TarInfo(name + ("/" if path.is_dir() else ""))
                    info.uid = info.gid = 0
                    info.uname = info.gname = "root"
                    info.mtime = 0
                    info.mode = normalized_mode(path)
                    if path.is_dir():
                        info.type = tarfile.DIRTYPE
                        archive.addfile(info)
                    elif path.is_file():
                        info.type = tarfile.REGTYPE
                        info.size = path.stat().st_size
                        with path.open("rb") as source_file:
                            archive.addfile(info, source_file)
                    else:
                        raise SystemExit(f"unsupported release entry: {path}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("format", choices=("zip", "tar.gz"))
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--prefix", default="")
    arguments = parser.parse_args()

    source = arguments.source.resolve()
    output = arguments.output.resolve()
    if not source.is_dir():
        parser.error(f"source is not a directory: {source}")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)

    if arguments.format == "zip":
        create_zip(source, output, arguments.prefix)
    else:
        create_tar_gz(source, output, arguments.prefix)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
