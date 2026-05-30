---
description: 跑 Planner→Generator→Evaluator 三智能体 harness 循环，把一个需求自动拆解、实现、独立验收到全部通过。
argument-hint: <自然语言需求>
---

你现在是 OPD harness 的**编排者（主线程）**。请把用户需求跑通三智能体循环：

> 需求：$ARGUMENTS

**严格按步骤调度，不要替 Planner/Generator/Evaluator 干活**——你只负责调度子代理、读写共享状态、置位与控制提交节奏。

## 共享状态
- feature 清单：`docs/exec-plans/active/<slug>/features.json`（Default-FAIL，**唯一真相源**）
- 反馈日志：`docs/exec-plans/active/<slug>/feedback.md`（append-only：每轮 Evaluator 结论）
- 工作日志：`docs/logging.md`（结束时按其模板在**顶部**追加一条）
- 检查点：git commit（每个 feature 通过即一次提交）

## ① 规划
1. 用 **planner** 子代理处理需求。
2. planner 返回后，读它产出的 `plan.md` 与 `features.json`，向用户**简述** slug 与 feature 列表。
3. 若 planner 列出**需人决策**项：停下，把问题清晰抛给用户，等回复后再继续；否则进入 ②。

## ② 逐 feature 循环（连续跑）
对 `features.json` 中按 `priority` 排序、`passes:false` 的 feature，**逐个**处理。对每个 feature：

重复至多 **3 轮**：
1. 用 **generator** 子代理实现 / 修订该 feature。给它：feature 的 id 与完整条目、`features.json` 路径、`feedback.md` 路径（让它读最新反馈）。
2. 用 **evaluator** 子代理复验。给它：同一 feature 条目、generator 刚返回的复验命令与改动摘要、相关路径。**evaluator 必须是全新调用（全新上下文）**。
3. 把 evaluator 的结论**追加**到 `feedback.md`（标注 feature id、轮次、时间、VERDICT 与反馈）。
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
- 非侵入式：留意并质疑任何对 `verl/`、`LlamaFactory/` 的改动。
- 不 push、不做不可逆操作，除非用户明确同意。
