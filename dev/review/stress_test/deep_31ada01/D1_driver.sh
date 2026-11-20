#!/bin/bash
# Runs every D1 case; a case that kills R is recorded as "crash" and the run restarts after it.
# Usage: R_LIBS=<library with the multigrain build> bash D1_driver.sh   (writes D1_sweep.tsv next to this script)
dir=$(cd "$(dirname "$0")" && pwd); out=$dir/D1_sweep.tsv; prog=$dir/D1_progress.txt
export LC_ALL=en_US.UTF-8
rm -f "$out"; start=1
while true; do
  timeout 900 Rscript "$dir/D1_runner.R" "$dir" "$start" "$out" "$prog" > "$dir/D1_runner.log" 2>&1; code=$?
  last=$(cat "$prog")
  [ "$last" = "done" ] && break
  name=$(cd "$dir" && Rscript -e "source('D1_cases.R'); cat(names(cases)[$last])")
  printf "%s\tcrash\texit %s\t\t\t\n" "$name" "$code" >> "$out"
  start=$((last + 1))
done
rm -f "$prog" "$dir/D1_runner.log"
echo finished
