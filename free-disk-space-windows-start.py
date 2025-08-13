"""
Start freeing disk space on Windows in the background by launching
the existing PowerShell cleanup script, while recording a PID file
and redirecting logs, so later steps can wait for completion.
"""

import os
import sys
import subprocess
from pathlib import Path


# Get the temporary directory set by GitHub Actions
def get_temp_dir() -> Path:
    return Path(os.environ.get("RUNNER_TEMP"))


def main() -> int:
    print("Starting Windows disk cleanup...")
    script_dir = Path(__file__).resolve().parent
    cleanup_script = script_dir / "free-disk-space-windows.ps1"
    if not cleanup_script.exists():
        print(f"::error file={__file__}::Cleanup script '{cleanup_script}' not found")
        return 1

    temp_dir = get_temp_dir()
    pid_file = temp_dir / "free-disk-space.pid"
    log_file_path = temp_dir / "free-disk-space.log"

    if pid_file.exists():
        print(f"::error file={__file__}::Pid file '{pid_file}' already exists")
        return 1

    # Launch the PowerShell cleanup in the background and redirect logs
    try:
        with open(log_file_path, "w", encoding="utf-8") as log_file:
            proc = subprocess.Popen(
                [
                    "pwsh",
                    # Suppress PowerShell startup banner/logo for cleaner logs.
                    "-NoLogo",
                    # Don't load user/system profiles. Ensures a clean, predictable environment.
                    "-NoProfile",
                    # Disable interactive prompts. Required for CI to avoid hangs.
                    "-NonInteractive",
                    # Execute the specified script file (next argument).
                    "-File",
                    str(cleanup_script),
                ],
                # Write child stdout to the log file
                stdout=log_file,
                # Merge stderr into stdout for a single, ordered log stream
                stderr=subprocess.STDOUT,
            )
    except FileNotFoundError:
        print("::error::pwsh not found on PATH; cannot start disk cleanup.")
        return 1

    pid_file.write_text(str(proc.pid))
    print(
        f"::notice file={__file__}::Started free-disk-space cleanup in background. "
        f"pid={proc.pid}; log_file: {log_file_path}; pid_file: {pid_file}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
