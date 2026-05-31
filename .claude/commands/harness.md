---
description: 跑 Planner→Generator→Evaluator 三智能体 harness 循环，把一个需求自动拆解、实现、独立验收到全部通过。
argument-hint: <自然语言需求>
---

你现在是 OPD harness 的**编排者（主线程）**。请把用户需求跑通三智能体循环：

> 需求：$ARGUMENTS

**严格按步骤调度，不要替 Planner/Generator/Evaluator 干活**——你只负责调度子代理、读写共享状态、置位与控制提交节奏。

## 共享状态
- feature 清单：`docs/exec-plans/active/<slug>/features.json`（Default-FAIL，**唯一真相源**）
- 进度文件：`docs/exec-plans/active/<slug>/progress.md`（append-only：启动、恢复、轮次、commit、暂停原因）
- 反馈日志：`docs/exec-plans/active/<slug>/feedback.md`（append-only：每轮 Evaluator 结论）
- 工作日志：`docs/logging.md`（结束时按其模板在**顶部**追加一条）
- 检查点：git commit（每个 feature 通过即一次提交）

## ① 启动 / 恢复
1. 先检查 `docs/exec-plans/active/`。
2. 若用户明确要求继续、resume、续跑，或 active 下只有一个 slug：跳过 planner，读取该 slug 的 `features.json`、`progress.md`、`feedback.md` 与 `git log --oneline -15`，进入恢复对账。
3. 若 active 下有多个 slug 且用户未指定：停下，让用户选择 slug。
4. 若没有可恢复 slug：用 **planner** 子代理处理需求。
5. planner 返回后，读它产出的 `plan.md`、`features.json` 与 `progress.md`，向用户**简述** slug 与 feature 列表。
6. 若 planner 列出**需人决策**项：停下，把问题清晰抛给用户，等回复后再继续；否则进入 ②。

### 恢复对账
恢复已有 slug 时按顺序处理：
1. `git status --short` 不干净时，判断改动是否属于该 slug 的上轮产物、编排者置位或外部改动；不能归因就停下问人。
2. `feedback.md` 最新轮是 PASS 但 `features.json` 仍为 `passes:false`：只补置该 feature 的 `passes:true`，追加 `progress.md`，再选下一个 feature。
3. Generator 已提交但没有对应 Evaluator 反馈：直接调用 evaluator 复验该 feature，不重跑 generator。
4. 最新反馈是 FAIL：把反馈交给 generator 进入下一轮。
5. 没有轮次记录：从 priority 最小的 `passes:false` feature 开始。
6. 每次恢复判断、轮次开始/结束、提交、暂停原因都追加到 `progress.md`。

## ② 逐 feature 循环（连续跑）
对 `features.json` 中按 `priority` 排序、`passes:false` 的 feature，**逐个**处理。对每个 feature：

重复至多 **3 轮**：
1. 用 **generator** 子代理实现 / 修订该 feature。给它：feature 的 id 与完整条目、`features.json` 路径、`progress.md` 路径、`feedback.md` 路径（让它读最新反馈）。
2. 用 **evaluator** 子代理复验。给它：同一 feature 条目、generator 刚返回的复验命令与改动摘要、`features.json` / `progress.md` / `feedback.md` 路径。**evaluator 必须是全新调用（全新上下文）**。
3. 把 evaluator 的结论**追加**到 `feedback.md`（标注 feature id、轮次、时间、VERDICT 与反馈），并把轮次摘要追加到 `progress.md`。
4. 分支：
   - **PASS**：把 `features.json` 里该 feature 的 `"passes"` 改成 `true`（**只改这一个字段**）；确认 generator 已提交（若没有，你补一次描述性 commit）；跳出本 feature 循环，进入下一个 feature。
   - **FAIL**：带着反馈回到第 1 步，再来一轮。
   - **UNVERIFIED / 需人决策**：停下，把待决策问题抛给用户。

若 3 轮仍未 PASS：停下，汇总卡点与最后一次反馈，作为「需人决策」交还用户。

## ③ 收尾
当**所有** feature `passes:true`，或你因「需人决策」/ 超预算停下时：
1. 按 `docs/logging.md` 模板，在**顶部**追加一条工作日志（状态 / 做了什么 / 涉及 / 注意 / 下一步 / 需人决策）。
2. 若本需求**全部完成**：把 `docs/exec-plans/active/<slug>/` 整个移到 `docs/exec-plans/completed/<slug>/`，并提交。
3. 给用户简洁总结：完成了哪些 feature、哪些待决策、git 提交了哪些。

## 纪律
- 一次只推进一个 feature；Generator 也只啃一个（对抗一把梭）。
- **你（编排者）是唯一能把 `passes` 置 `true` 的人**，且仅在 evaluator 判 PASS 之后。
- `features.json` 参考 Anthropic `feature_list.json`：顶层 JSON 数组；每项是端到端能力；核心字段为 `category` / `description` / `steps` / `passes:false`，OPD 只增加 `id` / `priority` / `verify` / `needs_human`。
- 除 `passes` 外，不改写已有 feature 定义；如验收标准确实需要变更，停下交给用户确认。
- 非侵入式：留意并质疑任何对 `verl/`、`LlamaFactory/` 的改动。
- 技术债不属于 Planner/Generator/Evaluator 主循环；不要在 harness 中要求三角色登记或清理技术债，相关治理走独立定时任务 / 人工排期。
- 不 push、不做不可逆操作，除非用户明确同意。
