#!/usr/bin/env python3
"""Interactive CLI for the jump-start Agno agent."""

from __future__ import annotations

import sys
from collections.abc import Iterator
from typing import TYPE_CHECKING, Any

from agno.run.agent import RunEvent, RunOutput
from agno.utils import pprint
from dotenv import load_dotenv

load_dotenv()

SESSION_ID = "jump-start-cli"

if TYPE_CHECKING:
    from agno.agent import Agent


def _prompt_yes_no(prompt: str, *, default: str = "n") -> bool:
    while True:
        choice = input(f"{prompt} [y/n] (default {default}): ").strip().lower()
        if not choice:
            choice = default
        if choice in ("y", "yes"):
            return True
        if choice in ("n", "no"):
            return False
        print("Please enter y or n.")


def _emit_stream_event(event: Any) -> bool:
    """Print a stream event. Returns True if response content was emitted."""
    event_type = getattr(event, "event", None)

    if event_type == RunEvent.run_content.value:
        content = getattr(event, "content", None)
        if content:
            print(content, end="", flush=True)
            return True
        return False

    if event_type == RunEvent.tool_call_started.value:
        tool = getattr(event, "tool", None)
        if tool is not None:
            print(f"\n[tool] {tool.tool_name}({tool.tool_args})", flush=True)
        else:
            print("\n[tool] (started)", flush=True)
        return False

    if event_type == RunEvent.tool_call_completed.value:
        tool = getattr(event, "tool", None)
        name = tool.tool_name if tool is not None else "unknown"
        print(f"[tool done] {name}", flush=True)
        return False

    if event_type == RunEvent.run_error.value:
        content = getattr(event, "content", None)
        if content:
            print(f"\n[error] {content}", flush=True)
        return False

    return False


def _consume_stream(stream: Iterator[Any]) -> tuple[Any | None, bool]:
    """Consume a run/continue stream; return final output and whether content streamed."""
    run_output = None
    streamed_content = False

    for event in stream:
        if _emit_stream_event(event):
            streamed_content = True
        if getattr(event, "is_paused", False):
            run_output = event
        elif isinstance(event, RunOutput):
            run_output = event

    if streamed_content:
        print()

    return run_output, streamed_content


def _stream_run(agent: Agent, message: str) -> tuple[Any | None, bool]:
    stream = agent.run(
        message,
        session_id=SESSION_ID,
        stream=True,
        stream_events=True,
    )
    return _consume_stream(stream)


def _stream_continue(agent: Agent, run_response: Any) -> tuple[Any | None, bool]:
    stream = agent.continue_run(
        run_id=run_response.run_id,
        session_id=run_response.session_id,
        requirements=run_response.requirements,
        stream=True,
        stream_events=True,
    )
    return _consume_stream(stream)


def resolve_requirements(run_response: Any) -> None:
    """Collect user answers for paused requirements (mutates requirements in place)."""
    print("\n--- Agent needs your input ---")

    for requirement in run_response.active_requirements:
        if requirement.needs_user_input:
            input_schema = requirement.user_input_schema
            if input_schema:
                user_values: dict[str, str] = {}
                for field in input_schema:
                    name = field.name  # type: ignore[attr-defined]
                    description = field.description or ""  # type: ignore[attr-defined]
                    field_type = field.field_type or "str"  # type: ignore[attr-defined]
                    print(f"\nField: {name}")
                    if description:
                        print(f"Description: {description}")
                    print(f"Type: {field_type}")
                    if field.value is None:  # type: ignore[attr-defined]
                        user_values[name] = input(f"Enter value for {name}: ").strip()
                    else:
                        print(f"Value: {field.value}")  # type: ignore[attr-defined]
                        user_values[name] = field.value  # type: ignore[attr-defined]
                requirement.provide_user_input(user_values)
            continue

        if requirement.needs_confirmation:
            tool_exec = requirement.tool_execution
            tool_name = tool_exec.tool_name if tool_exec else "unknown"
            tool_args = tool_exec.tool_args if tool_exec else {}
            print("\nConfirmation required")
            print(f"Tool: {tool_name}")
            print(f"Args: {tool_args}")
            if _prompt_yes_no("Run this tool?", default="n"):
                requirement.confirm()
                print("Approved.")
            else:
                requirement.reject()
                print("Rejected.")


def run_turn(agent: Agent, message: str) -> None:
    """Run one user message through the agent, handling HITL pauses with streaming."""
    run_response, streamed = _stream_run(agent, message)

    while run_response and getattr(run_response, "is_paused", False):
        resolve_requirements(run_response)
        run_response, continued_streamed = _stream_continue(agent, run_response)
        streamed = streamed or continued_streamed

    if not streamed and run_response and getattr(run_response, "content", None):
        pprint.pprint_run_response(run_response, markdown=True)


def main() -> None:
    from jump_start_agent.agent import build_jump_start_agent

    agent = build_jump_start_agent()

    if len(sys.argv) > 1:
        prompt = " ".join(sys.argv[1:])
        run_turn(agent, prompt)
        return

    print("=" * 80)
    print("Jump Start Demo agent (empty line to exit)")
    print("Example: Create a fraud detection demo with transactions and fraud-alerts topics")
    while True:
        try:
            line = input("\n> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break
        if not line:
            break
        run_turn(agent, line)


if __name__ == "__main__":
    main()
