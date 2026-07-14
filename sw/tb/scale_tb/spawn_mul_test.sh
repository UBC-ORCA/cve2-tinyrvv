#!/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <num_processes> <binary>"
    echo "Example:"
    echo "  $0 16 build/orca_cve2_fp4_scale_0.1/lint_scale_e4m3_no_fuse-verilator/Ve4m3_mul"
    exit 1
fi

NUM_PROCS="$1"
BIN="$2"

if [[ ! -x "$BIN" ]]; then
    echo "Error: '$BIN' does not exist or is not executable."
    exit 1
fi

mkdir -p logs

echo "Launching $NUM_PROCS processes..."

for ((i=0; i<NUM_PROCS; i++)); do
    echo "  Worker $i"

    "$BIN" \
        --a-offset "$i" \
        --a-stride "$NUM_PROCS" \
        > "logs/worker_${i}.log" 2>&1 &
done

wait

echo "All workers completed."