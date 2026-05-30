# OPD Harness 设计：Planner / Generator / Evaluator 三智能体

> 把 README「harness 构造简介」的理念，落地成一套可一键运行的 `/harness` 工作流。

## 1. 背景与来源

长任务的核心难题：agent 跨多个上下文窗口工作，每个新会话**没有上一段的记忆**（像换班的工程师）。仅靠 compaction 不够，会出现两种失败：

- **一把梭**：想一次做完，跑断上下文，留下半成品 + 没文档；下一段只能猜。
- **过早完工**：后来的 agent 看到「有进展」就宣布完成。

Anthropic《Effective harnesses for long-running agents》(2025-11) 给了几个**可直接复用的原语**：Default-FAIL 的 feature 列表（JSON）、进度文件、git 检查点、开工自检例程、**一次只做一个 feature**、用真实测试自验证。

本项目在此之上，把「自验证」**上升为独立的 Evaluator**——因为「自己给自己打分」是核心失败模式；独立判别器（GAN 式思路）提供质量梯度，比让 generator 自我批判更可控、更易调。

**与 README 三支柱的映射：**

| README 支柱 | 在本 harness 中的落点 |
|------|------|
| 上下文管理 | Planner 产出 `features.json`/`plan.md` + 渐进式文档 + Generator 开工自检例程 |
| 验证与反馈 | 独立只读 Evaluator + `feedback.md` + 可观测的 `verify`/lint/工作日志 |
| 技术债清理 | 干净收尾（lint+commit）+ `exec-plans/{active,completed}` 生命周期 + `tech-debt-tracker.md` |

## 2. 三个角色

| 角色 | 文件 | 职责 | 工具边界 | 默认模型 |
|------|------|------|----------|----------|
| **Planner** | `.claude/agents/planner.md` | 需求 → 小而可独立验证的 Default-FAIL `features.json` + `plan.md` | 读 + Write（**只写** `exec-plans/`，不碰源码） | opus |
| **Generator** | `.claude/agents/generator.md` | 实现/修订**单个** feature，自检后留干净状态（lint+commit） | 全量（含 Edit/Bash） | sonnet |
| **Evaluator** | `.claude/agents/evaluator.md` | 独立复验单个 feature，取证打分，出 PASS/FAIL+反馈 | **只读**（Read/Grep/Glob/Bash，**无 Write/Edit**） | opus |

**为什么要分开？** 一个 agent 无法可靠地评判自己的产出。把生成与评判拆成两个角色（哪怕是同一模型的不同提示词），Evaluator 以**全新上下文**复验、且没有 Write 权限——它「没看过 Generator 的推理过程」，只能用证据说话。把一个独立 Evaluator 调得足够怀疑，远比把 Generator 调得自我批判更容易。

## 3. 共享状态文件（append-only handoff）

**角色之间不做内存通信**，全部通过文件 + 子代理返回报告交接：

- `docs/exec-plans/active/<slug>/features.json` — feature 清单，**唯一真相源**。schema：
  ```json
  {
    "id": "F1",
    "category": "functional|infra|doc|eval",
    "description": "完成后系统能做什么",
    "priority": 1,
    "steps": ["端到端验证步骤..."],
    "verify": "可直接执行的校验命令（&& 连接）",
    "needs_human": false,
    "passes": false
  }
  ```
  约束：每项初始 `passes:false`；**只有编排者**能在 Evaluator 判 PASS 后置 `true`；任何人不得删改 feature。用 JSON 是因为模型比改 Markdown 更不易把它改坏。
- `docs/exec-plans/active/<slug>/plan.md` — 人类可读摘要 + 需人决策清单。
- `docs/exec-plans/active/<slug>/feedback.md` — **append-only**，每轮 Evaluator 的 VERDICT 与反馈。
- `docs/logging.md` — 跨会话工作日志，harness 收尾时按其模板在顶部追加一条。
- **git commit** — 每个 feature 通过即一次描述性提交，作为可回滚检查点。

## 4. 编排循环

```
/harness "<需求>"   ← 主线程（编排者）执行
   │
   ├─① planner 子代理 ──► features.json（全部 passes:false）+ plan.md
   │        plan.md 标了「需人决策」→ 停，交还用户
   │
   └─② 按 priority 取一个 passes:false 的 feature，循环（≤3 轮）：
          ├─ generator 子代理（feature + feedback.md 最新反馈）► 改码 + 自检 + commit
          ├─ evaluator 子代理（全新上下文, 只读）► Default-FAIL 取证 ► PASS / FAIL+反馈
          ├─ 追加结论到 feedback.md
          └─ PASS → 编排者置 passes:true、确认已 commit → 下一个 feature
             FAIL → 带反馈再来一轮
             3 轮未过 / UNVERIFIED → 停，报「需人决策」
   └─③ 全部通过或触发决策点：写 docs/logging.md；全部完成则 active/<slug>/ → completed/
```

**为什么编排放在主线程**：Claude Code 子代理各自跑在**全新隔离上下文**、把最终报告返回调用方，但子代理一般**不能再 spawn 子代理**。因此「planner→(generator↔evaluator) 循环」必须由主线程（`/harness` 命令模板）驱动；这也天然保证了 Evaluator 的全新上下文。

**暂停点（连续跑、遇决策才停）**：planner 标注需人决策、Evaluator 给出 UNVERIFIED/需人决策、或单 feature 超 3 轮仍 FAIL。其余情况自动推进到下一个 feature。

## 5. 关键原则

1. **Default-FAIL 契约**：每个判据默认失败，必须取证才能 PASS。
2. **独立、只读、全新上下文的 Evaluator**：对抗自评。
3. **一次一个 feature**：对抗一把梭与上下文耗尽。
4. **干净收尾**：每轮结束 lint 通过 + 描述性 commit，仓库随时可合并。
5. **增量 + 可恢复**：feature 级 commit + 进度文件，随时能从上次状态接着干。
6. **非侵入式**：不动 vendored 的 `verl/`、`LlamaFactory/`（见 `docs/dev.md`）。
7. **smoke-first / GPU 敏感**：默认只跑廉价校验（lint、dry-run、tiny-config smoke）；完整训练/评测是 GPU 重活（8×5090 32G），标 `needs_human`，由人决策后再跑。

## 6. 如何使用

```text
/harness <自然语言需求>
```

例：`/harness "给 scripts/val/eval 的生成结果加一层本地缓存，避免重复推理"`

- 流程会自动：拆 feature → 逐个实现+独立验收 → 通过即提交 → 收尾写日志。
- 需人决策时会停下来问你；回复后可再次 `/harness` 或直接让我续跑。
- 运行产物在 `docs/exec-plans/active/<slug>/`；全部完成后移到 `completed/`。

**与既有约定的关系**：
- `docs/dev.md`：harness 是「每次只做一件事 + 测试驱动 + 收工写日志」这套规范的自动化执行体。
- `docs/logging.md`：收尾日志按其「结构化字段·最新在上」模板追加。
- `docs/exec-plans/`：沿用 `active/ → completed/` 生命周期。

## 7. 调参与维护

- **模型分配**：Generator 用较便宜的模型跑量、Evaluator 用较强模型做判断，可在各 agent frontmatter 的 `model` 调整。
- **迭代上限**：默认单 feature 3 轮，可在 `.claude/commands/harness.md` 调整。
- **harness 审计**：博客明确告诫——随着模型增强，应定期审查 harness 里哪些组件是为了弥补**已不再存在**的模型局限，测试后**主动删冗余**，避免过度工程化。
