#!/usr/bin/env python3
"""Exercise native MLX and INDIGO's routed OpenAI chat API on a Mac."""

from __future__ import annotations

import json
import os
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


HOST_URL = os.environ.get("INDIGO_MLX_HOST_URL", "http://127.0.0.1:10733").rstrip("/")
ROUTER_URL = os.environ.get("INDIGO_ROUTER_URL", "http://127.0.0.1:10732").rstrip("/")
MODEL = os.environ.get("INDIGO_MLX_ACCEPTANCE_MODEL", "mlx/default_model")
TIMEOUT = int(os.environ.get("INDIGO_ACCEPTANCE_TIMEOUT", "300"))


def get_json(url: str) -> dict:
    with urlopen(url, timeout=TIMEOUT) as response:
        return json.load(response)


def chat(body: dict) -> dict | list[dict]:
    request = Request(
        f"{ROUTER_URL}/v1/chat/completions",
        data=json.dumps({"model": MODEL, **body}).encode(),
        headers={"Content-Type": "application/json"},
    )
    with urlopen(request, timeout=TIMEOUT) as response:
        if not body.get("stream"):
            return json.load(response)
        chunks = []
        for raw_line in response:
            line = raw_line.decode().strip()
            if not line.startswith("data:"):
                continue
            data = line.removeprefix("data:").strip()
            if data == "[DONE]":
                break
            chunks.append(json.loads(data))
        return chunks


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def main() -> None:
    health = get_json(f"{HOST_URL}/health")
    require(health.get("status") == "ok", f"native MLX is unhealthy: {health}")
    host_models = get_json(f"{HOST_URL}/v1/models")
    require(host_models.get("data"), "native MLX returned no models")
    routed_models = get_json(f"{ROUTER_URL}/v1/models")
    routed_ids = [item.get("id") for item in routed_models.get("data", [])]
    require(MODEL in routed_ids, f"router did not list {MODEL}: {routed_ids}")
    print(f"models: native={host_models['data'][0].get('id')} routed={MODEL}")

    chunks = chat(
        {
            "messages": [{"role": "user", "content": "Reply with the word INDIGO_READY."}],
            "stream": True,
            "temperature": 0,
            "max_tokens": 256,
        }
    )
    require(isinstance(chunks, list) and chunks, "stream returned no data chunks")
    streamed_text = "".join(
        choice.get("delta", {}).get("content") or ""
        for chunk in chunks
        for choice in chunk.get("choices", [])
    )
    failures = []
    if "INDIGO_READY" not in streamed_text:
        failures.append(f"streamed reply missed the requested text: {streamed_text!r}")
    if "<|" in streamed_text:
        failures.append(f"streamed reply leaked model control tokens: {streamed_text!r}")
    print(f"stream: {streamed_text.strip()[:160]}")

    tool = {
        "type": "function",
        "function": {
            "name": "get_temperature",
            "description": "Get the current temperature in a city.",
            "parameters": {
                "type": "object",
                "properties": {"city": {"type": "string"}},
                "required": ["city"],
            },
        },
    }
    user = {
        "role": "user",
        "content": "Use get_temperature to find the current temperature in Boston. Do not guess it.",
    }
    tool_reply = chat(
        {
            "messages": [user],
            "tools": [tool],
            "tool_choice": "required",
            "stream": False,
            "temperature": 0,
            "max_tokens": 256,
        }
    )
    require(isinstance(tool_reply, dict), "tool-call response was not JSON")
    assistant = tool_reply["choices"][0]["message"]
    calls = assistant.get("tool_calls") or []
    if not calls:
        failures.append(f"model did not issue a structured tool call: {assistant}")
        raise RuntimeError("; ".join(failures))
    call = calls[0]
    require(call.get("function", {}).get("name") == "get_temperature", f"unexpected tool call: {call}")
    arguments = json.loads(call["function"]["arguments"])
    require("boston" in arguments.get("city", "").lower(), f"unexpected tool arguments: {arguments}")
    require(call.get("id"), f"tool call has no ID: {call}")
    print(f"tool call: {call['function']['name']}({arguments})")

    final_reply = chat(
        {
            "messages": [
                user,
                assistant,
                {
                    "role": "tool",
                    "tool_call_id": call["id"],
                    "name": "get_temperature",
                    "content": json.dumps({"city": "Boston", "celsius": 17}),
                },
            ],
            "tools": [tool],
            "stream": False,
            "temperature": 0,
            "max_tokens": 256,
        }
    )
    require(isinstance(final_reply, dict), "tool-result response was not JSON")
    final_text = final_reply["choices"][0]["message"].get("content") or ""
    require("17" in final_text, f"assistant did not use the tool result: {final_text!r}")
    print(f"tool result: {final_text.strip()[:160]}")
    require(not failures, "; ".join(failures))
    print("MLX routed acceptance passed")


if __name__ == "__main__":
    try:
        main()
    except (HTTPError, URLError, KeyError, ValueError, RuntimeError) as error:
        if isinstance(error, HTTPError):
            detail = error.read(1000).decode(errors="replace")
            print(f"MLX routed acceptance failed: {error}: {detail}", file=sys.stderr)
        else:
            print(f"MLX routed acceptance failed: {error}", file=sys.stderr)
        sys.exit(1)
