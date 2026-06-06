import copy
import sys
from pathlib import Path
from typing import Any

import yaml


def deep_merge(base: Any, overlay: Any) -> Any:
    if isinstance(base, dict) and isinstance(overlay, dict):
        merged = copy.deepcopy(base)
        for key, value in overlay.items():
            merged[key] = deep_merge(merged[key], value) if key in merged else copy.deepcopy(value)
        return merged
    return copy.deepcopy(overlay)


def load_yaml(path: Path) -> Any:
    with path.open() as f:
        return yaml.safe_load(f) or {}


def main() -> None:
    if len(sys.argv) not in {3, 4}:
        raise SystemExit("usage: render-hermes-config.py BASE OUTPUT [MCP_OVERLAY]")

    base_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    overlay_path = Path(sys.argv[3]) if len(sys.argv) == 4 else None

    config = load_yaml(base_path)
    if overlay_path and overlay_path.is_file():
        config = deep_merge(config, load_yaml(overlay_path))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w") as f:
        yaml.safe_dump(config, f, sort_keys=False)


if __name__ == "__main__":
    main()
