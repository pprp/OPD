# OPD 实验设计（测什么、怎么判定）

> 北极星：**复现 / 证伪** README 与论文《Rethinking On-Policy Distillation》关于 OPD 的结论。
> 机制见 [opd-method.md](opd-method.md)，执行流程见 [harness.md](harness.md)。

## 复现目标（来自 README）

- 已发布产物：`Qwen3-1.7B-SFT`（SFT 冷启动）、`Qwen3-4B-Base-GRPO`（零 RL 基线）。
- 评测：AIME24 / AIME25 / AMC23，用 `scripts/val/eval/{gen_vllm,grade}.py`（复用 JustRL pipeline）。
- 资源现实：论文 8×A800 80GB；本地 8×5090 32GB → 必须调小 batch / 序列长度（见 `docs/env.md`）。

## 论文可检验主张 → 实验映射

| 主张 | 旋钮 / 做法 | 判据 |
|---|---|---|
| C1 师生需共享「思考模式」 | 同族 vs 跨族师生；`enable_thinking` 对齐 | 匹配组优于不匹配组 |
| C2 教师须提供「学生没有的新能力」 | 弱→强反向蒸馏（同族 1.5B/7B 教师） | 弱教师无增益（与学生不可区分） |
| 机制：少量共享 token 承载 97–99% 质量 | `TOP_K_STRATEGY` 消融 + `distillation/overlap_ratio` | 高 overlap 伴随成功对齐 |
| 救援1 off-policy cold start | 先 SFT（`vllm_rollout`→LlamaFactory）再 OPD | 冷启动救回失败 OPD |
| 救援2 teacher-aligned prompt 选择 | 数据筛选（`dedup_deepmath` / 选 prompt） | 选择后 OPD 改善 |
| 代价：长程蒸馏是否 scale | 增大 `MAX_RESP_LENGTH` | 稠密奖励优势随长度衰减 |

## 实验因子总表（冻结无关变量，一次只动一个）

| 因子 | env | 取值 |
|---|---|---|
| 算法 | `ADV_ESTIMATOR` | token_reward_direct / _plus_grpo / token_grpo / grpo |
| top-k 预算 | `LOG_PROB_TOP_K` | 0（采样态 OPD）/ 16 / … |
| token 集策略 | `TOP_K_STRATEGY` | only_stu / only_tch / intersection / union / union-intersection |
| K 维加权 | `REWARD_WEIGHT_MODE` | student_p / teacher_p / none |
| 教师温度 | `TEACHER_TEMPERATURE` | 1.0 / … |
| 师生对 | `ACTOR_MODEL_PATH` / `REWARD_MODEL_PATH` | 见脚本注释清单 |
| 数据 | `TRAIN_DATASET` | dapo-math-17k / DeepMath / OpenThoughts3 … |
| 采样数 | `N_RESPONSES` | 4 / 8 / … |
| 混合权重 | `GRPO_OUTCOME_WEIGHT` | 1.0 / … |

## 实验卡片 = `features.json` 中的一项

工作单元沿用 [harness.md](harness.md) 定义的 `features.json` schema（`passes:false` 默认 + 独立验证）。一次实验就是一个 `category:"eval"` 项；因为完整训练是 GPU 重活，按 harness.md 原则 7 标 `needs_human:true`。实验语义（假设 / 冻结变量 / 判据）写进 `description` / `steps` / `verify`，细节可放同目录 `plan.md`：

```json
{
  "id": "EXP-007",
  "category": "eval",
  "description": "固定 LOG_PROB_TOP_K=16、REWARD_WEIGHT_MODE=student_p、师生=DS-R1-1.5B/JustRL-1.5B、数据=dapo-math-17k；验证 only_tch 在 AIME24 不劣于 only_stu（差 ≤ 1pt）",
  "priority": 3,
  "steps": [
    "only_stu / only_tch 各跑一次 on_policy_distillation.sh（仅改 TOP_K_STRATEGY，冻结其余）",
    "训练完用 scripts/val 独立评 AIME24 avg@16",
    "比较两者差值是否满足判据"
  ],
  "verify": "cd scripts/val/eval && python gen_vllm.py && python grade.py   # 判据: only_tch_avg@16 >= only_stu_avg@16 - 1.0",
  "needs_human": true,
  "passes": false
}
```

`passes` 默认 `false`（= 未证实），只有 Evaluator 独立复测满足 `verify` 判据后，才由编排者置 `true`——对抗「自评」。

## 评测协议（务必遵守）

- **绕开 verl v0.7.0 内置验证**：它会低估 5–7pt（README IMPORTANT）。设 `trainer.test_freq=-1`、`MAX_VAL_RESP_LENGTH=MAX_RESP_LENGTH`，训练完用 `scripts/val/` 独立评。
- 指标用 **avg@k**（`val_kwargs.n=16`，T=0.7，top_p=0.95）。
- 证据三件套：swanlab run id、`validation_log/<EXPERIMENT_NAME>/`、`grading_results.json`。

## 本地资源约束（5090 32GB）

先 smoke（dev.md）：小 `MAX_RESP_LENGTH`（如 3072）、`MINI_BATCH_SIZE` 调小、`N_RESPONSES=4`、必要时 `param_offload=True`，确认链路通再放大。精度看 `MODEL_DTYPE`（fp32 / bfloat16）。

## 已登记 seed 实验（Default-FAIL，待补全 / 执行）

- **EXP-001 链路 smoke**：`token_reward_direct` 跑通 1 step，loss/reward 有限、出 swanlab 曲线。
- **EXP-002 基线**：`grpo`（`LOG_PROB_TOP_K=0`）复现 `Qwen3-4B-Base-GRPO` 量级。
- **EXP-003** only_stu vs only_tch（见上方模板）。
- **EXP-004** `reward_weight_mode` 三选项消融。
- **EXP-005** 弱→强反向蒸馏（C2）。
- **EXP-006** off-policy cold start 救援（失败 OPD → SFT → 复跑）。

> 正式登记进 `docs/exec-plans/active/<slug>/features.json`，由 harness 流程（Planner 产出、Evaluator 复验）驱动。
