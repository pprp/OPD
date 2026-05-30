# OPD 机制与数学（本仓库实现）

> 本文是 OPD 在**本仓库 verl 实现**里的「地面真相」：代码到底怎么算。
> 研究主张与实验见 [experiments.md](experiments.md)，执行流程见 [harness.md](harness.md)。
> 改动以下文件属于改 vendored `verl/`，遵循 `docs/dev.md` 的「非侵入式」原则。

## 一句话

OPD = 学生（actor）on-policy 采样 → 对每个响应 token 位置取 top-K 候选词 → 用教师（`reward_model` 槽位里的冻结 LM）在这些词上的 log-prob，算出一个**逐 token 的稠密奖励 = 候选词上加权的 −KL(学生‖教师)** → 该奖励**直接当作 advantage**（`token_reward_direct`，无 group baseline，这是与 GRPO 的关键区别）→ 喂进 PPO 策略损失。

## 数据流

1. 学生采样 N 条响应（`rollout.n=N_RESPONSES`，vLLM）。
2. 算 student top-K：每个位置学生分布的 top-K token 及 log-prob（`student_top_k_ids` / `student_top_k_log_probs`）。
3. 教师前向：`reward_model`（=教师 LM）在相关 token 上给 log-prob；可选 `teacher_temperature` 缩放 logits。得到 `teacher_on_student_log_probs` 等。
4. 算逐 token 奖励 `rm_scores`（`dp_actor.compute_distillation_reward`）。
5. advantage：`token_reward_direct` 把 `rm_scores * response_mask` 直接当 advantage 与 returns。
6. loss：advantage 进 PPO 策略损失（`loss_agg_mode`），KL-to-ref 可选（`USE_KL`）。

## 核心公式（以 `only_stu` 为例）

位置 t、候选 k：

- 学生 log-prob `S[t,k]`，教师在同一候选上的 log-prob `T_on_S[t,k]`
- 逐对 log-ratio：`kl_val[t,k] = S[t,k] − T_on_S[t,k]`
- 权重 `w[t,k]`（K 维）：`student_p` = softmax_k(S)；`teacher_p` = softmax_k(T_on_S)；`none` = 均匀
- **奖励**：`rm_score[t] = Σ_k w[t,k] · (T_on_S[t,k] − S[t,k])`　（即代码里的 `-kl_val * norm_weights`）

直觉：教师比学生更偏好的 token 给正奖励，把学生推向教师；且只在学生**自己访问到的状态**上对齐——这就是 on-policy 蒸馏。`token_reward_direct` 不做组内归一，稠密信号本身即 advantage。

## 五种 `top_k_strategy`（在哪些 token 上算 KL）

| 策略 | 含义 | KL 项 |
|---|---|---|
| `only_stu` | 学生 top-K，查教师 logp（默认） | `S − T_on_S` |
| `only_tch` | 教师 top-K，查学生 logp | `S_on_T − T_logp` |
| `intersection` | 仅两边都在 top-K 的 token（`overlap_mask`） | masked `S − T_on_S` |
| `union` | 两边并集，去掉教师里已在学生集合中的重复（`teacher_in_student_mask`） | union logp 差 |
| `union-intersection` | 对称差（恰在一边），且 `normalize=False`（用原始概率不 softmax） | union logp 差 |

> 论文「少量共享 token 承载 97–99% 概率质量」的机制分析，对应这些策略 + verl 已并入的 `distillation/overlap_ratio` / `overlap_token_advantage` 指标（见 README News 2026-05-26）。

## `reward_weight_mode`（K 维如何加权）

`compute_reward_weights`：`student_p` / `teacher_p` 对所选 logp 在 K 维做 softmax 归一；`none` 用均匀分布；非法值报错。`union-intersection` 走未归一的原始概率分支。

## `adv_estimator` 变体

| 取值 | 含义 |
|---|---|
| `token_reward_direct` | 稠密 KL 奖励**直接**当 advantage（OPD 主线） |
| `token_reward_direct_plus_grpo` | `adv = direct + grpo_outcome_weight · grpo_adv`（稠密蒸馏 + 稀疏正确性） |
| `token_grpo` | token 级 GRPO 变体 |
| `grpo` | 纯 RL 基线（配 `LOG_PROB_TOP_K=0`） |

`grpo_outcome_weight` 由 env `GRPO_OUTCOME_WEIGHT` 控制。

## 教师如何接入

教师走 verl 的 **`reward_model` 槽位**，但不是标量 RM——是一整个冻结 LM，用 logp 当稠密奖励：

```
reward_model.enable=True
reward_model.model.path=$REWARD_MODEL_PATH            # 教师
+actor_rollout_ref.rollout.log_prob_top_k=$LOG_PROB_TOP_K
+actor_rollout_ref.rollout.top_k_strategy=$TOP_K_STRATEGY
+actor_rollout_ref.rollout.reward_weight_mode=$REWARD_WEIGHT_MODE
+actor_rollout_ref.rollout.teacher_temperature=$TEACHER_TEMPERATURE
```

## 关键代码位置

| 关注点 | 位置 |
|---|---|
| advantage（direct / +grpo / token_grpo / grpo） | `verl/verl/trainer/ppo/core_algos.py:264,330,854-924` |
| 逐 token 奖励 + 5 策略 + 加权 | `verl/verl/workers/actor/dp_actor.py:451-624` |
| 教师/topk 前向、`teacher_temperature` | `verl/verl/workers/fsdp_workers.py:1925-2020,2249,2611-2645` |
| 旋钮默认值 | `verl/verl/workers/config/rollout.py:142-145` |
| adv 分发 | `verl/verl/trainer/ppo/ray_trainer.py:181,1118-1132` |
| `grpo_outcome_weight` 配置 | `verl/verl/trainer/config/algorithm.py:351` |
| 入口接线 | `on_policy_distillation.sh:171-245` |
