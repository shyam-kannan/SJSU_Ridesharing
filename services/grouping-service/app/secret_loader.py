from pathlib import Path
import os


def load_mounted_secrets(mount_path: str = "/mnt/secrets-store") -> None:
    secret_dir = Path(mount_path)
    if not secret_dir.exists():
        return

    for entry in secret_dir.iterdir():
        if not entry.is_file():
            continue
        if os.getenv(entry.name):
            continue
        os.environ[entry.name] = entry.read_text(encoding="utf-8").strip()