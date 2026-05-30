# 环境说明

## 硬件与系统

- 操作系统：Ubuntu（内核 `Linux 6.8.0-40-generic`）
- GPU：8× NVIDIA GeForce RTX 5090（单卡 32 GB 显存，驱动 580.105.08）
- CUDA：13.0
- 系统 Python：3.10.12；包/工具管理：uv 0.11.2

> 注意：论文实验在 8× A800 80GB 上完成；本地为 8× 5090 32GB，单卡显存更小。复现时需相应调小 batch、序列长度等显存敏感配置。

## 项目与 conda 环境

两个训练栈使用各自独立的 conda 环境，互不污染：

- **OPD / RL**：基于 verl（vendored，v0.7.0），环境 `verl`（Python 3.12）

  ```bash
  conda create -n verl python==3.12
  conda activate verl
  cd verl/
  USE_MEGATRON=0 bash scripts/install_vllm_sglang_mcore.sh
  pip install math-verify
  ```

- **SFT**：基于 LlamaFactory（vendored，v0.9.5），环境 `sft`（Python 3.11）

  ```bash
  conda create -n sft python==3.11
  conda activate sft
  cd LlamaFactory/
  pip install -e .
  pip install -r requirements/metrics.txt
  ```

> `verl/` 与 `LlamaFactory/` 是 vendored 目录（非 git submodule）。修改时遵循非侵入式原则，见 `docs/dev.md`。

## 关键入口与目录

| 用途 | 入口 / 路径 |
|------|------------|
| OPD（on-policy distillation） | `bash on_policy_distillation.sh`（`ADV_ESTIMATOR=token_reward_direct`） |
| RL（GRPO） | `bash grpo.sh`（`ADV_ESTIMATOR=grpo`、`LOG_PROB_TOP_K=0`） |
| SFT teacher rollout | `python scripts/infer/vllm_rollout.py` |
| SFT 训练 | `llamafactory-cli train LlamaFactory/examples/train_full/qwen3_base_full_sft.yaml` |
| 评测（生成 + 评分） | `scripts/val/eval/gen_vllm.py`、`scripts/val/eval/grade.py` |
| 训练数据 | `datasets/`（训练 parquet）、`datasets/test_data/` |
| 评测数据 | `scripts/val/data/` |
| 运行日志 | `logs/`（运行脚本时自动创建） |

> 各入口的完整参数说明见 `README.md` 的「Getting Started」章节。
