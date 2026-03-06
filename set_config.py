#!/usr/bin/env python3
"""
set_config.py
Usage: set_config.py <config_path> <dot.key.path> <value>
"""
import sys, yaml
from pathlib import Path

def set_key(d, keys, val):
    k = keys[0]
    if len(keys) == 1:
        try:
            parsed = yaml.safe_load(val)
        except Exception:
            parsed = val
        d[k] = parsed
        return
    if k not in d or not isinstance(d[k], dict):
        d[k] = {}
    set_key(d[k], keys[1:], val)

def main():
    if len(sys.argv) != 4:
        print("Usage: set_config.py <config_path> <dot.key.path> <value>", file=sys.stderr)
        sys.exit(2)
    cfg_path = Path(sys.argv[1])
    key = sys.argv[2]
    val = sys.argv[3]
    if not cfg_path.exists():
        print(f"Config file not found: {cfg_path}", file=sys.stderr)
        sys.exit(3)
    cfg = yaml.safe_load(cfg_path.read_text()) or {}
    set_key(cfg, key.split('.'), val)
    cfg_path.write_text(yaml.dump(cfg, default_flow_style=False))
    print(f"Updated {key} = {val} in {cfg_path}")

if __name__ == "__main__":
    main()