"""Optional, Linux-only release of unused native heap pages after inference.

This never unloads YOLO weights or restarts the worker, avoiding cold model loads.
Disabled by default until measured against real image workloads.
"""
import ctypes
from functools import lru_cache
import os
import sys


def trim_enabled() -> bool:
    return os.getenv("AI_TRIM_HEAP_AFTER_INFERENCE", "false").strip().lower() in {
        "1", "true", "yes", "on"
    }


@lru_cache(maxsize=1)
def _malloc_trim():
    if not sys.platform.startswith("linux"):
        return None
    try:
        libc = ctypes.CDLL("libc.so.6")
        operation = libc.malloc_trim
        operation.argtypes = [ctypes.c_size_t]
        operation.restype = ctypes.c_int
        return operation
    except (OSError, AttributeError):
        return None


def trim_unused_heap_if_enabled() -> bool:
    if not trim_enabled():
        return False
    operation = _malloc_trim()
    if operation is None:
        return False
    return bool(operation(0))
