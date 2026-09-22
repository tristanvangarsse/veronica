#!/usr/bin/env python3
"""Veronica command-line entry point.

The production-proven media engine remains implemented in media_maintenance.py.
This wrapper gives the future macOS application a stable product-facing entry point
without duplicating any processing logic.
"""
from media_maintenance import main


if __name__ == "__main__":
    raise SystemExit(main())
