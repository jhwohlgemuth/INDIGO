#!/usr/bin/env python3
"""Check that a locally downloaded MLX model has complete safetensors shards."""

from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path


class ModelError(Exception):
    pass


def shard_tensors(path: Path, expected: set[str] | None) -> None:
    size = path.stat().st_size
    with path.open("rb") as stream:
        prefix = stream.read(8)
        if len(prefix) != 8:
            raise ModelError(f"truncated safetensors file: {path}")
        (header_size,) = struct.unpack("<Q", prefix)
        if header_size == 0 or header_size > size - 8:
            raise ModelError(f"invalid safetensors header: {path}")
        header = json.loads(stream.read(header_size))

    tensors = {name: value for name, value in header.items() if name != "__metadata__"}
    if not tensors:
        raise ModelError(f"no tensors in {path}")
    if expected is not None and set(tensors) != expected:
        raise ModelError(f"tensor names do not match the index: {path}")

    last_byte = 0
    for name, value in tensors.items():
        offsets = value.get("data_offsets")
        if not isinstance(offsets, list) or len(offsets) != 2:
            raise ModelError(f"invalid offsets for {name}: {path}")
        start, end = offsets
        if not isinstance(start, int) or not isinstance(end, int) or start < 0 or end < start:
            raise ModelError(f"invalid offsets for {name}: {path}")
        last_byte = max(last_byte, end)
    if 8 + header_size + last_byte != size:
        raise ModelError(f"truncated or oversized safetensors file: {path}")


def check_model(directory: Path) -> None:
    if not directory.is_dir():
        raise ModelError(f"model directory does not exist: {directory}")

    config = directory / "config.json"
    if not config.is_file():
        raise ModelError(f"missing config.json: {directory}")
    json.loads(config.read_text())
    if not any((directory / name).is_file() for name in ("tokenizer.json", "tokenizer.model")):
        raise ModelError(f"missing tokenizer: {directory}")

    index = directory / "model.safetensors.index.json"
    if index.is_file():
        weight_map = json.loads(index.read_text()).get("weight_map")
        if not isinstance(weight_map, dict) or not weight_map:
            raise ModelError(f"invalid weight index: {index}")
        shards = {}
        for tensor, filename in weight_map.items():
            if not isinstance(filename, str) or Path(filename).name != filename:
                raise ModelError(f"invalid shard name in index: {filename}")
            shards.setdefault(filename, set()).add(tensor)
    else:
        shards = {path.name: None for path in directory.glob("*.safetensors")}
        if not shards:
            raise ModelError(f"no safetensors weights found: {directory}")

    for filename, expected in sorted(shards.items()):
        path = directory / filename
        if not path.is_file():
            raise ModelError(f"missing weight shard: {path}")
        shard_tensors(path, expected)

    incomplete = list((directory / ".cache" / "huggingface" / "download").glob("*.incomplete"))
    if incomplete:
        raise ModelError(f"unfinished download: {incomplete[0]}")

    total = sum((directory / filename).stat().st_size for filename in shards)
    print(f"MLX model ready: {directory} ({len(shards)} weight shard(s), {total:,} bytes)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model_dir", type=Path)
    args = parser.parse_args()
    try:
        check_model(args.model_dir)
    except (ModelError, OSError, ValueError, TypeError, json.JSONDecodeError) as error:
        print(f"MLX model check failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
