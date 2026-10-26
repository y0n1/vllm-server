#!/usr/bin/env bash

set -euo pipefail

pip install b12x
vllm download-kernels
vllm serve --config /home/vllm/recipe/config.vision.yaml
