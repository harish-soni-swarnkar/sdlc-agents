---
paths:
  - "**/*.py"
---
# Python rules

A floor, not a style guide — where this project already has a convention, follow it.

- Types: full hints on public functions; clean under `mypy`/`pyright` strict; no bare `Any`;
  use dataclasses / TypedDict / pydantic models for structured data instead of raw dicts.
- Boundaries: validate external input with pydantic or explicit checks.
- Errors: no bare `except:`; no silent `except Exception: pass`.
- I/O: `pathlib` for paths; context managers for files and connections.
- Money: `decimal.Decimal`, never `float`.
- No mutable default arguments.
