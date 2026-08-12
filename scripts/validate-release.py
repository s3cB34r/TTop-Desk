#!/usr/bin/env python3
"""Validate TTop Desk release sources and optionally generated artifacts."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import re
import subprocess
import tarfile
import zipfile
from pathlib import Path, PurePosixPath


PLUGIN_ID = "io.github.s3cb34r.ttopdesk"
CATALOG = "plasma_applet_io.github.s3cb34r.ttopdesk.mo"
FORBIDDEN_NAMES = {".git", "__pycache__", ".pytest_cache", "tests", "visual"}
FORBIDDEN_BYTES = (
    b"/data/Projects/TTop-Desk",
    b"/home/yannic",
    b"/tmp/ttop-desk",
    b"/workspace/",
)


def safe_name(name: str) -> PurePosixPath:
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts:
        raise AssertionError(f"unsafe archive path: {name}")
    return path


def assert_clean_name(name: str) -> None:
    path = safe_name(name)
    if any(part in FORBIDDEN_NAMES or part.endswith(".pyc") for part in path.parts):
        raise AssertionError(f"developer/cache entry in release: {name}")


def assert_portable_bytes(name: str, payload: bytes) -> None:
    for needle in FORBIDDEN_BYTES:
        if needle in payload:
            raise AssertionError(f"development path leak in {name}: {needle.decode()}")


def read_version(root: Path) -> str:
    version = (root / "VERSION").read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise AssertionError(f"invalid VERSION: {version!r}")
    return version


def validate_source(root: Path) -> str:
    version = read_version(root)
    metadata = json.loads((root / "package/metadata.json").read_text(encoding="utf-8"))
    plugin = metadata["KPlugin"]
    assert plugin["Id"] == PLUGIN_ID
    assert plugin["Version"] == version, "metadata version differs from VERSION"
    assert plugin["License"] == "GPL-3.0-or-later"

    cmake = (root / "CMakeLists.txt").read_text(encoding="utf-8")
    assert "file(STRINGS \"${CMAKE_CURRENT_SOURCE_DIR}/VERSION\"" in cmake
    assert not re.search(r"project\(ttop-desk VERSION [0-9]", cmake)

    for required in (
        "LICENSE",
        "CHANGELOG.md",
        "RELEASE-NOTES.md",
        "release/install.sh",
        "release/uninstall.sh",
        "release/README.md",
        "release/backend-README.md",
        "release/ttop-desk-backend.service.in",
    ):
        assert (root / required).is_file(), f"missing release source: {required}"

    for script_name in ("release/install.sh", "release/uninstall.sh"):
        script = (root / script_name).read_text(encoding="utf-8")
        assert "/data/Projects/TTop-Desk" not in script
        assert not re.search(r"(^|[;&|]\s*)sudo(?:\s|$)", script, re.MULTILINE)

    service = (root / "release/ttop-desk-backend.service.in").read_text(
        encoding="utf-8"
    )
    assert "RestrictAddressFamilies=AF_UNIX" in service
    assert "UMask=0077" in service
    assert "PrivateTmp=true" not in service
    assert "AF_INET" not in service
    assert not re.search(r"(?m)^User=", service)
    assert "/data/Projects/TTop-Desk" not in service
    return version


def zip_entries(path: Path) -> dict[str, bytes]:
    with zipfile.ZipFile(path) as archive:
        result: dict[str, bytes] = {}
        for info in archive.infolist():
            assert_clean_name(info.filename)
            if not info.is_dir():
                result[info.filename] = archive.read(info)
        return result


def tar_entries(path: Path) -> dict[str, bytes]:
    with tarfile.open(path, "r:gz") as archive:
        result: dict[str, bytes] = {}
        for member in archive.getmembers():
            assert_clean_name(member.name)
            if member.isfile():
                extracted = archive.extractfile(member)
                assert extracted is not None
                result[member.name] = extracted.read()
            elif not member.isdir():
                raise AssertionError(f"unsupported archive entry: {member.name}")
        return result


def validate_checksums(dist: Path) -> None:
    lines = (dist / "SHA256SUMS").read_text(encoding="utf-8").splitlines()
    assert lines, "SHA256SUMS is empty"
    names: list[str] = []
    for line in lines:
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        assert match, f"invalid checksum line: {line}"
        expected, name = match.groups()
        safe_name(name)
        payload_path = dist / name
        assert payload_path.is_file(), f"checksummed file missing: {name}"
        actual = hashlib.sha256(payload_path.read_bytes()).hexdigest()
        assert actual == expected, f"checksum mismatch: {name}"
        names.append(name)
    assert names == sorted(names), "SHA256SUMS entries are not sorted"


def validate_dist(root: Path, dist: Path, version: str) -> None:
    expected_files = {
        "CHANGELOG.md",
        "LICENSE",
        "README.md",
        "RELEASE-NOTES.md",
        "SHA256SUMS",
        "VERSION",
        "install.sh",
        "uninstall.sh",
        f"locale/de/LC_MESSAGES/{CATALOG}",
        f"ttop-desk-{version}.plasmoid",
        f"ttop-desk-backend-{version}.tar.gz",
        f"ttop-desk-{version}-linux.tar.gz",
    }
    actual_files = {
        path.relative_to(dist).as_posix() for path in dist.rglob("*") if path.is_file()
    }
    assert actual_files == expected_files, (
        f"unexpected dist contents; missing={sorted(expected_files - actual_files)}, "
        f"extra={sorted(actual_files - expected_files)}"
    )
    validate_checksums(dist)

    plasmoid_name = f"ttop-desk-{version}.plasmoid"
    plasmoid = zip_entries(dist / plasmoid_name)
    for required in (
        "metadata.json",
        "contents/ui/main.qml",
        "contents/config/main.xml",
        "contents/ui/TTop/Runtime/qmldir",
        "contents/ui/TTop/Runtime/libttopruntimeplugin.so",
    ):
        assert required in plasmoid, f"plasmoid entry missing: {required}"
    packaged_metadata = json.loads(plasmoid["metadata.json"].decode("utf-8"))
    assert packaged_metadata["KPlugin"]["Version"] == version
    assert not any(name.startswith("package/") for name in plasmoid)
    for name, payload in plasmoid.items():
        assert_portable_bytes(f"{plasmoid_name}:{name}", payload)

    backend_name = f"ttop-desk-backend-{version}.tar.gz"
    backend = tar_entries(dist / backend_name)
    backend_root = f"ttop-desk-backend-{version}/"
    required_backend = {
        backend_root + "LICENSE",
        backend_root + "README.md",
        backend_root + "VERSION",
        backend_root + "ttop-desk-backend.service.in",
        backend_root + "ttop_backend/__init__.py",
        backend_root + "ttop_backend/main.py",
        backend_root + "ttop_backend/protocol.py",
        backend_root + "ttop_backend/processes.py",
        backend_root + "ttop_backend/gpu/nvidia.py",
    }
    assert required_backend <= backend.keys(), "backend archive is incomplete"
    assert all(name.startswith(backend_root) for name in backend)
    for name, payload in backend.items():
        assert_portable_bytes(f"{backend_name}:{name}", payload)

    bundle_name = f"ttop-desk-{version}-linux.tar.gz"
    bundle = tar_entries(dist / bundle_name)
    bundle_root = f"ttop-desk-{version}-linux/"
    required_bundle = {
        bundle_root + "install.sh",
        bundle_root + "uninstall.sh",
        bundle_root + "README.md",
        bundle_root + "RELEASE-NOTES.md",
        bundle_root + "CHANGELOG.md",
        bundle_root + "LICENSE",
        bundle_root + "VERSION",
        bundle_root + "SHA256SUMS",
        bundle_root + plasmoid_name,
        bundle_root + backend_name,
        bundle_root + f"locale/de/LC_MESSAGES/{CATALOG}",
    }
    assert required_bundle == bundle.keys(), "full release bundle contents differ"
    for name, payload in bundle.items():
        assert_portable_bytes(f"{bundle_name}:{name}", payload)

    # Validate the checksums embedded in the full bundle without extracting it.
    checksum_payload = bundle[bundle_root + "SHA256SUMS"].decode("utf-8")
    for line in checksum_payload.splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  (.+)", line)
        assert match, f"invalid bundled checksum line: {line}"
        expected, name = match.groups()
        payload = bundle.get(bundle_root + name)
        assert payload is not None, f"bundled checksum target missing: {name}"
        assert hashlib.sha256(payload).hexdigest() == expected


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--dist", type=Path)
    arguments = parser.parse_args()
    root = arguments.root.resolve()
    version = validate_source(root)
    if arguments.dist is not None:
        validate_dist(root, arguments.dist.resolve(), version)
    print(f"Release validation passed for {version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
