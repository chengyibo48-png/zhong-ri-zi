"""Keep project checks and their isolated save data on the project drive."""
import tempfile
from pathlib import Path

TEMP_ROOT = Path(__file__).resolve().parents[1] / '.build' / 'runtime-tmp'

def temporary_directory(*, prefix):
    TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    return tempfile.TemporaryDirectory(prefix=prefix, dir=str(TEMP_ROOT))
