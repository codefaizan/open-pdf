#!/usr/bin/env python3
"""Copy a Mach-O binary and its non-system dylibs into a self-contained lib folder."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

SYS_PREFIXES = (
    "/System/",
    "/usr/lib/",
)


def otool_deps(binary: Path) -> list[str]:
    out = subprocess.check_output(["otool", "-L", str(binary)], text=True)
    deps: list[str] = []
    for line in out.splitlines()[1:]:
        line = line.strip()
        if not line:
            continue
        path = line.split(" (", 1)[0].strip()
        deps.append(path)
    return deps


def is_system(path: str) -> bool:
    return path.startswith(SYS_PREFIXES)


def resolve_dep(dep: str, current: Path, root_binary: Path) -> Path | None:
    if dep.startswith("@loader_path/"):
        candidate = (current.parent / dep[len("@loader_path/") :]).resolve()
        return candidate if candidate.is_file() else None
    if dep.startswith("@executable_path/"):
        candidate = (root_binary.parent / dep[len("@executable_path/") :]).resolve()
        return candidate if candidate.is_file() else None
    if dep.startswith("@rpath/"):
        name = Path(dep).name
        search_roots = [
            current.parent,
            Path("/opt/homebrew/lib"),
            Path("/usr/local/lib"),
        ]
        for base in search_roots:
            maybe = (base / name).resolve()
            if maybe.is_file():
                return maybe
        for opt in (Path("/opt/homebrew/opt"), Path("/usr/local/opt")):
            if not opt.is_dir():
                continue
            for lib in opt.glob(f"*/lib/{name}"):
                if lib.is_file():
                    return lib.resolve()
        return None
    if dep.startswith("@"):
        return None
    candidate = Path(dep).resolve()
    return candidate if candidate.is_file() else None


def collect_deps(root_binary: Path) -> dict[str, Path]:
    """Map install-name basename -> absolute resolved file path."""
    by_install_name: dict[str, Path] = {}
    queue = [root_binary.resolve()]
    seen: set[Path] = set()
    while queue:
        current = queue.pop()
        if current in seen:
            continue
        seen.add(current)
        for dep in otool_deps(current):
            if is_system(dep):
                continue
            # Skip the binary's own install id line.
            if Path(dep).resolve() == current:
                continue
            candidate = resolve_dep(dep, current, root_binary)
            if candidate is None:
                continue
            if candidate == current:
                continue
            install_name = Path(dep).name
            by_install_name[install_name] = candidate
            by_install_name.setdefault(candidate.name, candidate)
            queue.append(candidate)
    return by_install_name


def rewrite_install_names(binary: Path, bundled: dict[str, Path]) -> None:
    if binary.suffix == ".dylib" or ".dylib" in binary.name:
        # Keep the on-disk basename as the install id.
        subprocess.check_call(
            ["install_name_tool", "-id", f"@executable_path/lib/{binary.name}", str(binary)]
        )
    for dep in otool_deps(binary):
        name = Path(dep).name
        if name in bundled:
            subprocess.check_call(
                [
                    "install_name_tool",
                    "-change",
                    dep,
                    f"@executable_path/lib/{name}",
                    str(binary),
                ]
            )


def bundle_binary(source: Path, dest_dir: Path) -> Path:
    dest_dir.mkdir(parents=True, exist_ok=True)
    lib_dir = dest_dir / "lib"
    if lib_dir.exists():
        shutil.rmtree(lib_dir)
    lib_dir.mkdir(parents=True)

    dest = dest_dir / source.name
    shutil.copy2(source, dest)
    dest.chmod(dest.stat().st_mode | 0o111)

    bundled = collect_deps(source)
    # Copy once per unique file; prefer install-name basename on disk.
    copied_files: dict[Path, str] = {}
    for install_name, path in bundled.items():
        if path in copied_files:
            # Symlink alternate install names to the copied file.
            link = lib_dir / install_name
            if not link.exists():
                link.symlink_to(copied_files[path])
            continue
        target = lib_dir / install_name
        shutil.copy2(path, target)
        copied_files[path] = install_name

    rewrite_install_names(dest, bundled)
    for entry in lib_dir.iterdir():
        if entry.is_file() and not entry.is_symlink() and (
            entry.suffix == ".dylib" or ".dylib" in entry.name
        ):
            rewrite_install_names(entry, bundled)

    for path in sorted(lib_dir.iterdir(), reverse=True):
        if path.is_symlink() or not path.is_file():
            continue
        subprocess.check_call(["codesign", "--force", "--sign", "-", str(path)])
    subprocess.check_call(["codesign", "--force", "--sign", "-", str(dest)])

    return dest


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    parser.add_argument("dest_dir", type=Path)
    args = parser.parse_args(argv)
    if not args.binary.is_file():
        print(f"binary not found: {args.binary}", file=sys.stderr)
        return 1
    out = bundle_binary(args.binary.resolve(), args.dest_dir.resolve())
    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
