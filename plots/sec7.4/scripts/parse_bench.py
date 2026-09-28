#!/usr/bin/env python3
"""Print timings for selected benchmarks from `go test -bench` output.

Usage:
    parse_bench.py <data-file> <benchmark> [<benchmark> ...]

Benchmark names may be given with or without the "Benchmark" prefix,
e.g. `AttestCounter` or `BenchmarkAttestCounter`.

Example:
    parse_bench.py ../data-paper/swtpm-bench.data AttestCounter VerifyCounter
"""

import re
import sys

# BenchmarkAttestCounter-32    501    2354117 ns/op    57124 B/op    1740 allocs/op
BENCH_RE = re.compile(r"^Benchmark(\S+?)(?:-\d+)?\s+(\d+)\s+([\d.]+)\s+ns/op")


def parse(path):
    results = {}
    with open(path) as f:
        for line in f:
            m = BENCH_RE.match(line.strip())
            if m:
                results[m.group(1)] = float(m.group(3))
    return results


def main():
    if len(sys.argv) < 3:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(1)

    path, names = sys.argv[1], sys.argv[2:]
    results = parse(path)

    missing = False
    print(f"{'Benchmark':<24} {'ns/op':>14} {'ms/op':>10}")
    for name in names:
        name = name.removeprefix("Benchmark")
        ns = results.get(name)
        if ns is None:
            print(f"{name:<24} {'not found':>14}")
            missing = True
            continue
        print(f"{name:<24} {ns:>14.0f} {ns / 1e6:>10.3f}")

    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
