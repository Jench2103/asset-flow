#!/usr/bin/env python3
"""Run unit tests with output capture."""

import argparse
import os
import subprocess
import sys
from typing import TextIO


def main() -> int:
    parser: argparse.ArgumentParser = argparse.ArgumentParser(
        description="Run AssetFlow unit tests"
    )
    parser.add_argument(
        "-s", "--suite", help="Test suite name (e.g., DecimalParsingTests)"
    )
    parser.add_argument(
        "-o", "--output", help="Output filename (default: based on suite)"
    )
    parser.add_argument(
        "--no-parallel", action="store_true", help="Disable parallel testing"
    )
    parser.add_argument(
        "--timeout", type=int, help="Max seconds per test (prevents crash loops)"
    )
    args: argparse.Namespace = parser.parse_args()

    # Move to repo root
    repo_root: str = subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"], text=True
    ).strip()
    os.chdir(repo_root)

    # Determine output filename
    results_dir: str = ".claude/skills/test/results"
    output_file: str
    if args.output:
        output_file = f"{results_dir}/{args.output}"
    elif args.suite:
        output_file = f"{results_dir}/{args.suite}.txt"
    else:
        output_file = f"{results_dir}/all-tests.txt"

    # Clear previous output if exists (avoids stale data if build fails early)
    if os.path.exists(output_file):
        os.remove(output_file)

    # Build xcodebuild command
    cmd: list[str] = [
        "xcodebuild",
        "-project",
        "AssetFlow.xcodeproj",
        "-scheme",
        "AssetFlow",
        "test",
        "-destination",
        "platform=macOS",
    ]
    if args.suite:
        cmd.extend(["-only-testing:AssetFlowTests/" + args.suite])
    if args.no_parallel:
        cmd.extend(["-parallel-testing-enabled", "NO"])
    if args.timeout:
        cmd.extend(["-maximum-test-execution-time-allowance", str(args.timeout)])

    # Run tests (output saved to file, minimal console output)
    process: subprocess.Popen[str] = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )

    summary_line: str = ""
    xcresult_path: str = ""
    f: TextIO
    with open(output_file, "w") as f:
        if process.stdout:
            line: str
            for line in process.stdout:
                f.write(line)
                stripped: str = line.strip()
                # Capture summary line
                if (
                    "** TEST SUCCEEDED **" in stripped
                    or "** TEST FAILED **" in stripped
                ):
                    summary_line = stripped
                # Capture .xcresult path
                if stripped.endswith(".xcresult"):
                    xcresult_path = stripped

    process.wait()

    # Print summary and paths
    if summary_line:
        print(summary_line)
    else:
        print("Tests completed (no summary found).")
    print(f"Output: {output_file}")
    if xcresult_path:
        print(f"xcresult: {xcresult_path}")

    return process.returncode or 0


if __name__ == "__main__":
    sys.exit(main())
