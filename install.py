#!/usr/bin/env python3
"""cli-manager installer

Installs cli-manager either by building from source (default) or by
downloading a pre-compiled binary from GitHub Releases.

Usage:
  python3 install.py                        Build from source (requires Swift)
  python3 install.py --binary               Download a pre-compiled binary
  python3 install.py --binary --version v1.2.0
  python3 install.py --local                Install to ~/.config/cli-manager/bin
  python3 install.py --global               Install to /usr/local/bin

Options:
  --binary            Download a pre-compiled binary from GitHub Releases
  --version <tag>     Pin to a specific release tag (requires --binary)
  --local             Install to ~/.config/cli-manager/bin (mirrors quickinstall.py default)
  --global            Install to /usr/local/bin instead of ./bin
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

# quickinstall.py lives alongside this script and contains all shared
# utilities (colours, helpers, platform detection, GitHub API, download).
sys.path.insert(0, str(Path(__file__).resolve().parent))
from quickinstall import (  # noqa: E402
    GITHUB_REPO,
    BOLD, RESET, GRAY, YELLOW,
    ok, warn, fail, info,
    detect_platform,
    fetch_release_metadata,
    download_binary,
    write_repo_config,
)

# Directory that contains this script (the cloned repo root).
SCRIPT_DIR = Path(__file__).resolve().parent


# ── Argument parsing ───────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="cli-manager installer",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--binary",
        action="store_true",
        help="Download a pre-compiled binary from GitHub Releases",
    )
    parser.add_argument(
        "--version",
        default="latest",
        metavar="TAG",
        help="Pin to a specific release tag, e.g. v1.2.0 (requires --binary)",
    )
    parser.add_argument(
        "--local",
        dest="local_install",
        action="store_true",
        help="Install to ~/.config/cli-manager/bin (mirrors quickinstall.py default)",
    )
    parser.add_argument(
        "--global",
        dest="global_install",
        action="store_true",
        help="Install to /usr/local/bin instead of ./bin",
    )
    return parser.parse_args()


# ── Binary installation ────────────────────────────────────────────────────────

def copy_to_destination(src: Path, local_install: bool, global_install: bool) -> None:
    """Copy the built/downloaded binary to its final destination."""
    global_bin = Path("/usr/local/bin")

    if global_install:
        dest = global_bin / "cli-manager"
        info(f"Installing to {BOLD}{dest}{RESET}")
        if os.access(global_bin, os.W_OK):
            shutil.copy2(src, dest)
            dest.chmod(0o755)
        else:
            warn(f"{global_bin} is not writable — using sudo")
            subprocess.run(["sudo", "cp", str(src), str(dest)], check=True)
            subprocess.run(["sudo", "chmod", "+x", str(dest)], check=True)
        write_repo_config(SCRIPT_DIR)
        ok(f"Installed.  Run: {BOLD}cli-manager{RESET}")
    elif local_install:
        bin_dir = Path.home() / ".config" / "cli-manager" / "bin"
        bin_dir.mkdir(parents=True, exist_ok=True)
        dest = bin_dir / "cli-manager"
        shutil.copy2(src, dest)
        dest.chmod(0o755)
        write_repo_config(SCRIPT_DIR)
        ok(f"Installed.  {GRAY}{dest}{RESET}")
        info(f"Add {BOLD}{bin_dir}{RESET} to your PATH to run as {BOLD}cli-manager{RESET}")
    else:
        bin_dir = SCRIPT_DIR / "bin"
        bin_dir.mkdir(exist_ok=True)
        dest = bin_dir / "cli-manager"
        shutil.copy2(src, dest)
        dest.chmod(0o755)
        write_repo_config(SCRIPT_DIR)
        ok(f"Installed.  Run: {BOLD}./bin/cli-manager{RESET}")
        info(f"Or add {BOLD}{bin_dir}{RESET} to your PATH to run as {BOLD}cli-manager{RESET}")


# ── Install from GitHub ────────────────────────────────────────────────────────

def install_from_github(version: str, local_install: bool, global_install: bool) -> None:
    os_name, arch = detect_platform()
    asset_name = f"cli-manager-{os_name}-{arch}"

    print()
    print(f"{BOLD}Downloading cli-manager…{RESET}  {GRAY}{GITHUB_REPO}{RESET}")
    print()
    info("Fetching release metadata…")

    release = fetch_release_metadata(version)
    tag_name = release.get("tag_name", "?")

    download_url = next(
        (a["browser_download_url"] for a in release.get("assets", [])
         if a.get("name") == asset_name),
        "",
    )

    if not download_url:
        available = [a["name"] for a in release.get("assets", [])]
        detail = ""
        if available:
            detail = "\nAssets available in this release:\n  " + "\n  ".join(available)
        fail(
            f"No binary found for {BOLD}{asset_name}{RESET} in release "
            f"{BOLD}{tag_name}{RESET}.{detail}\n"
            f"Build from source instead: {BOLD}python3 install.py{RESET} (without --binary)"
        )

    info(f"Downloading {BOLD}{asset_name}{RESET}  {GRAY}@ {tag_name}{RESET}")

    with tempfile.NamedTemporaryFile(delete=False) as tmp:
        tmp_path = Path(tmp.name)

    try:
        download_binary(download_url, tmp_path)
        tmp_path.chmod(0o755)
        print()
        copy_to_destination(tmp_path, local_install, global_install)
    finally:
        tmp_path.unlink(missing_ok=True)


# ── Build from source ──────────────────────────────────────────────────────────

BUILD_VERSION_SWIFT = SCRIPT_DIR / "Sources" / "CLIManager" / "BuildVersion.swift"
_VERSION_RE = re.compile(r'(let buildVersion\s*=\s*")([^"]+)(")')


def stamp_version(build_date: str) -> str:
    """Append build date to the version string in BuildVersion.swift. Returns original text."""
    original = BUILD_VERSION_SWIFT.read_text()
    stamped = _VERSION_RE.sub(lambda m: f'{m.group(1)}{m.group(2)} ({build_date}){m.group(3)}', original, count=1)
    BUILD_VERSION_SWIFT.write_text(stamped)
    return original


def restore_version(original: str) -> None:
    """Restore BuildVersion.swift to its original content."""
    BUILD_VERSION_SWIFT.write_text(original)


def install_from_source(local_install: bool, global_install: bool) -> None:
    swift = shutil.which("swift")
    if not swift:
        fail(
            "swift not found in PATH.\n"
            f"Install the Swift toolchain from {BOLD}https://swift.org/download{RESET}\n"
            f"Or download a pre-compiled binary: {BOLD}python3 install.py --binary{RESET}"
        )
        return  # unreachable; satisfies type checker

    result = subprocess.run([swift, "--version"], capture_output=True, text=True)
    swift_version = result.stdout.splitlines()[0] if result.stdout else "unknown"

    build_date = datetime.now().strftime("%Y/%m/%d-%H:%M")

    print()
    print(f"{BOLD}Building cli-manager…{RESET}  {GRAY}{swift_version}{RESET}")
    print()

    original = stamp_version(build_date)
    try:
        # Stream build output indented for visual grouping.
        process = subprocess.Popen(
            [swift, "build", "-c", "release"],
            cwd=SCRIPT_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        for line in process.stdout or []:
            print("  " + line, end="")
        process.wait()
    finally:
        restore_version(original)

    if process.returncode != 0:
        fail("Build failed.")

    binary = SCRIPT_DIR / ".build" / "release" / "cli-manager"
    if not binary.exists():
        fail(f"Build succeeded but binary not found at {binary}")

    print()
    copy_to_destination(binary, local_install, global_install)


# ── Main ───────────────────────────────────────────────────────────────────────

def main() -> None:
    args = parse_args()
    if args.binary:
        install_from_github(args.version, args.local_install, args.global_install)
    else:
        install_from_source(args.local_install, args.global_install)
    print()


if __name__ == "__main__":
    main()
