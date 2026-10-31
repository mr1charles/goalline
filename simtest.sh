#!/bin/bash
# usage: simtest.sh N   -> runs N headless AI-vs-AI matches in parallel, prints summaries
N=${1:-6}
cd "$(dirname "$0")"
for i in $(seq 1 $N); do
  timeout 250 godot --headless --path . --fixed-fps 60 -- --autotest 2>&1 | grep -E "SUMMARY|ERROR|SCRIPT" &
done
wait
