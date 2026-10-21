#!/bin/bash
# Run a MATLAB plot script without opening the MATLAB desktop; the script exports its own PNGs.
#   bash _tools/plot.sh _raw/<experiment>/<name>_plot.m
# Takes ~20-40 s (MATLAB start-up). Figures are not shown on screen, only exported.
dir="$(cd "$(dirname "$1")" && (pwd -W 2>/dev/null || pwd))"
matlab -batch "run('$dir/$(basename "$1")')"
