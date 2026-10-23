"""Offline checks for the downloaded MLX model validator."""

from __future__ import annotations

import json
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CHECKER = Path(__file__).resolve().parents[1] / "scripts" / "mlx-model-check.py"


class MlxModelCheckTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.model = Path(self.temporary.name) / "model"
        self.model.mkdir()
        (self.model / "config.json").write_text('{"model_type":"gpt_oss"}')
        (self.model / "tokenizer.json").write_text("{}")
        (self.model / "model.safetensors.index.json").write_text(
            json.dumps({"weight_map": {"test.weight": "model-00001-of-00001.safetensors"}})
        )
        header = json.dumps(
            {"test.weight": {"dtype": "U8", "shape": [4], "data_offsets": [0, 4]}}
        ).encode()
        self.shard = self.model / "model-00001-of-00001.safetensors"
        self.shard.write_bytes(struct.pack("<Q", len(header)) + header + b"data")

    def check(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(CHECKER), str(self.model)],
            capture_output=True,
            text=True,
            check=False,
        )

    def test_complete_model(self) -> None:
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("MLX model ready", result.stdout)

    def test_missing_shard(self) -> None:
        self.shard.unlink()
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing weight shard", result.stderr)

    def test_truncated_shard(self) -> None:
        self.shard.write_bytes(self.shard.read_bytes()[:-1])
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("truncated or oversized", result.stderr)

    def test_unfinished_download(self) -> None:
        download = self.model / ".cache" / "huggingface" / "download"
        download.mkdir(parents=True)
        (download / "weights.incomplete").touch()
        result = self.check()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unfinished download", result.stderr)


if __name__ == "__main__":
    unittest.main()
