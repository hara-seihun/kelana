#!/usr/bin/env python3
"""Line-transaction and payload accounting for per-head direct GQA value reads."""
import argparse
import json


def costs(rank, *, groups=8, heads_per_group=2, head_dim=128, layers=28,
          context=4096, line=64, element_bytes=2, bandwidth=242e9):
    width = rank * element_bytes
    stride = groups * width
    padded_width = ((width + line - 1) // line) * line
    packed_lines = [((g * width % line) + width + line - 1) // line
                    for g in range(groups)]
    # Every head loads its group's values independently. A perfect shared
    # group load divides this per-head count by heads_per_group.
    compact_requests = heads_per_group * sum(packed_lines)
    padded_requests = heads_per_group * groups * (padded_width // line)
    dense_requests = heads_per_group * groups * (head_dim * element_bytes // line)
    dense_read = groups * heads_per_group * head_dim * element_bytes
    narrow_read = groups * heads_per_group * width
    return {
        "rank": rank, "context": context, "layers": layers, "line_bytes": line,
        "group_compact_lines": packed_lines,
        "per_key_layer_head_line_requests": {
            "dense": dense_requests, "compact": compact_requests, "padded": padded_requests
        },
        "per_key_layer_distinct_value_bytes": {
            "dense": groups * head_dim * element_bytes,
            "compact": stride, "padded": groups * padded_width
        },
        "per_key_layer_head_value_bytes": {
            "dense": dense_read, "compact": narrow_read,
            "padded": groups * heads_per_group * padded_width
        },
        "cache_bytes_all_layers": {
            "dense": layers * context * groups * 2 * head_dim * element_bytes,
            "compact": layers * context * (groups * head_dim * element_bytes + stride),
            "padded": layers * context * (groups * head_dim * element_bytes + groups * padded_width)
        },
        "decode_head_value_bytes_saved": {
            "compact": (dense_read - narrow_read) * context * layers,
            "padded": (dense_read - groups * heads_per_group * padded_width) * context * layers
        },
        "ideal_bandwidth_time_saved_ms": {
            "compact": (dense_read - narrow_read) * context * layers / bandwidth * 1e3,
            "padded": (dense_read - groups * heads_per_group * padded_width) * context * layers / bandwidth * 1e3
        }
    }


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--context", type=int, default=4096)
    p.add_argument("--layers", type=int, default=28)
    a = p.parse_args()
    print(json.dumps([costs(r, context=a.context, layers=a.layers)
                      for r in (24, 28, 32, 128)], indent=2))
