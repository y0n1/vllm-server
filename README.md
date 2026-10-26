# vLLM Server

This project packages a set of Docker Compose recipes for running self-hosted vLLM inference workloads with different model variants and GPU-optimized runtime settings. It is designed to make it easy to switch between local model configs while keeping one shared systemd service wrapper.

## What is in this repository

- `nvidia/` and `Nanbeige/` contain model-specific deployment folders, each with:
  - `compose.yaml` or `config.yml` for the container definition
  - `config.yaml` / `config.yml` for model runtime settings
- `etc/` contains model-selection environment files used by the systemd unit
- `vllm-server@.service` is a reusable systemd service template that starts a chosen model by swapping the `MODEL` environment file

## Included model presets

| Model preset | Folder | Notes |
| --- | --- | --- |
| Qwen3.8-Flash-Next-FP4-Local | `nvidia/Qwen3.8-Flash-Next-FP4-Local` | Uses `b12x` acceleration and FP4 / mixed-precision tuning |
| Qwen3.6-35B-A3B-NVFP4 | `nvidia/Qwen3.6-35B-A3B-NVFP4` | `Qwen3` reasoning + tool-call parser configuration |
| NVIDIA Nemotron 3.5 Bolt 74B | `nvidia/NVIDIA-Nemotron-3.5-Bolt-74B-A9B-24GB` | Speculative decoding and NVFP8 optimization |
| NVIDIA Nemotron 3.5 Super-VL 120B | `nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4` | Multi-modal configuration with media support |
| Nemotron 3 Nano Omni 30B | `nvidia/Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4` | Reasoning + multimodal / video-capable config |
| Nanbeige 4.3 33B | `Nanbeige/Nanbeige4.3-33B` | Tensor parallelism across 4 GPUs, 80% GPU memory utilization, and Qwen3 reasoning / Qwen3 Coder tool-call parsers |

## Requirements

- Linux host (DGX Spark with 128GB - preferred)
- NVIDIA GPU(s) with compatible drivers
- Docker and NVIDIA Container Toolkit installed
- A Hugging Face token in `HF_TOKEN`
- Network access to download model weights from the Hub or an already-populated local cache

## Environment setup

Set the Hugging Face token before starting any container:

```bash
export HF_TOKEN="your_token_here"
```

Each config in `etc/*.conf` maps a systemd instance to a model directory. For example:

```bash
cat etc/qwen-3.8-flash-next.conf
# MODEL=nvidia/Qwen3.8-Flash-Next-FP4-Local
```

## Quick start with Docker Compose

Choose a model folder and launch it directly:

```bash
cd /home/y0n1/Projects/vllm-server
export HF_TOKEN="your_token_here"

docker compose -f nvidia/Qwen3.8-Flash-Next-FP4-Local/compose.yaml \
  --project-name vllm-server up -d
```

The compose files use `network_mode: host`, so the server is expected to be reachable on the host's default vLLM port (typically `http://localhost:8000`).

## Quick verification

After startup, verify the OpenAI-compatible API is available:

```bash
curl http://localhost:8000/v1/models
```

You can also inspect the running container logs:

```bash
docker logs -f vllm-nvidia-Qwen3.8-Flash-Next-FP4-Local
```

## Systemd usage

The repository includes a templated service unit:

```bash
vllm-server@.service
```

This unit loads the selected model from an environment file in `etc/` and runs the matching compose file. Example:

```bash
systemctl --user daemon-reload
systemctl --user enable --now vllm-server@qwen-3.8-flash-next
```

This resolves the model from `etc/qwen-3.8-flash-next.conf` and starts the corresponding Docker Compose stack.
For Nanbeige 4.3 33B, enable `vllm-server@nanbeige-4.3-33b`; it uses `etc/nanbeige-4.3-33b.conf`.

## Notes on the runtime configuration

These profiles are tuned for latency, memory usage, and speculative decoding; many configs include settings such as:

- `trust-remote-code: true`
- `gpu-memory-utilization`
- `kv-cache-dtype: fp8`
- `enable-prefix-caching`
- `reasoning-parser` and `tool-call-parser`
- speculative decoding configurations like `mtp` or `dflash`

This makes the project useful for experimentation with advanced generation settings, multimodal models, and tool-calling inference workloads.

The Nanbeige 4.3 33B profile uses the `Nanbeige/Nanbeige4.3-33B` model with `tensor-parallel-size: 4` and `gpu-memory-utilization: 0.8`. It enables automatic tool choice and configures the `qwen3` reasoning parser with the `qwen3_coder` tool-call parser.

## Security and operational tips

- Never commit your `HF_TOKEN` to source control.
- Prefer `docker compose down` before switching model presets to avoid stale containers.
- Keep an eye on `/root/.cache/huggingface` and model cache volumes when running multiple presets.
- Some compose files mount GPU cache volumes for `vllm`, `flashinfer`, and `triton`; these are useful for performance but can consume significant disk space.

## Repository layout

```text
.
├── etc/
│   ├── default.conf
│   ├── nemotron-3.5-bolt.conf
│   ├── nemotron-3.5-super-vl.conf
│   ├── nemotron-3-nano-omni.conf
│   ├── nanbeige-4.3-33b.conf
│   ├── qwen-3.6-35b-a3b.conf
│   └── qwen-3.8-flash-next.conf
├── nvidia/
│   ├── NVIDIA-Nemotron-3.5-Bolt-74B-A9B-24GB/
│   ├── NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4/
│   ├── Nemotron-3-Nano-Omni-30B-A3B-Reasoning-NVFP4/
│   ├── Qwen3.6-35B-A3B-NVFP4/
│   └── Qwen3.8-Flash-Next-FP4-Local/
├── Nanbeige/
│   └── Nanbeige4.3-33B/
├── image.jpg
├── vllm-server@.service
├── .gitignore
└── README.md
```

## License

This repository does not currently declare a license file. If you plan to redistribute or fork it, confirm the appropriate licensing requirements for the model weights and any included container image sources before publishing.
