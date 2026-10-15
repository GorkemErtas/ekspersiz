"""Bound PyTorch CPU thread pools without changing models or inference thresholds."""
import os


def parse_cpu_thread_limit(value: str) -> int:
    """0 disables the override; values 1..16 bound CPU intra-op parallelism."""
    try:
        count = int(value)
    except (TypeError, ValueError) as exc:
        raise ValueError("AI_TORCH_NUM_THREADS must be an integer from 0 to 16") from exc
    if not 0 <= count <= 16:
        raise ValueError("AI_TORCH_NUM_THREADS must be an integer from 0 to 16")
    return count


def configure_torch_cpu_threads() -> int:
    """Called only during first YOLO model initialization, not at app import."""
    count = parse_cpu_thread_limit(os.getenv("AI_TORCH_NUM_THREADS", "2"))
    if count:
        import torch
        torch.set_num_threads(count)
    return count
