"""
Wait for the background Windows disk cleanup process started by
free-disk-space-windows-start.py, then print the full log.
"""

import os
import sys
import time
import ctypes
from pathlib import Path


# Get the temporary directory set by GitHub Actions
def get_temp_dir() -> Path:
    return Path(os.environ.get("RUNNER_TEMP"))


def is_process_running(pid: int) -> bool:
    PROCESS_QUERY_LIMITED_INFORMATION = 0x1000  # Sufficient for GetExitCodeProcess
    processHandle = ctypes.windll.kernel32.OpenProcess(
        PROCESS_QUERY_LIMITED_INFORMATION, 0, pid
    )
    if processHandle == 0:
        # Could be not running or we don't have sufficient rights to check
        return False
    else:
        ctypes.windll.kernel32.CloseHandle(processHandle)
    return True


def main() -> int:
    print("Waiting for Windows disk cleanup to finish...")
    temp_dir = get_temp_dir()
    pid_file = temp_dir / "free-disk-space.pid"
    log_file = temp_dir / "free-disk-space.log"

    if not pid_file.exists():
        print("::notice::No background free-disk-space process to wait for.")
        return 0

    try:
        pid = int(pid_file.read_text().strip().splitlines()[0])
    except Exception:
        # Delete the file if it exists
        pid_file.unlink(missing_ok=True)
        return 0

    # Poll until process exits
    while is_process_running(pid):
        time.sleep(3)

    # Delete the file if it exists
    pid_file.unlink(missing_ok=True)

    if log_file.exists():
        print("free-disk-space logs:")
        # Print entire log; replace undecodable bytes to avoid exceptions.
        try:
            with open(log_file, "r", encoding="utf-8", errors="replace") as f:
                print(f.read())
        except Exception as e:
            print(f"::warning::Failed to read log file '{log_file}': {e}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
