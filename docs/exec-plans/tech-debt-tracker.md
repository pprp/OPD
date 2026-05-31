# 技术债追踪（Tech Debt Tracker）

> 跨 slug、append-only 的**技术债登记簿**：记录后台扫描或人工审计发现的重复代码、偏离规范、不一致命名、文档漂移等问题。技术债治理与 `/harness` 的 Planner / Generator / Evaluator 主循环解耦，避免把实现验收流程变成无限 scope creep。

## 1. 为什么需要它

技术债需要独立账本，但不应该混进 feature 实现/验收循环：

- **Planner** 专注拆需求，不拉技术债清单。
- **Generator** 专注当前 feature，不登记或顺手清债。
- **Evaluator** 专注当前验收，不把非阻塞坏味道作为 FAIL 理由。
- **定时扫描 / 人工审计** 专门发现、登记、排期技术债。

这样做的目的：让 harness 的单 feature 验收保持可控，同时让技术债有单独入口、单独节奏、单独责任人。清理技术债时可以另起普通任务或 `/harness "清理 TD-xxx"`，但这属于新的需求，不由正在运行的 Planner/Generator/Evaluator 自动插单。

债的两个来源：

| 来源 | 谁登记 | 典型内容 |
|------|--------|----------|
| **定时扫描** | 独立扫描任务 | 重复代码、偏离规范、不一致命名、缺测试、文档漂移 |
| **人工审计** | 人或专门审计会话 | 架构风险、流程偏差、难以自动检测的问题 |

## 2. 与三智能体编排的边界

技术债追踪是独立流程，不嵌入 Planner→Generator→Evaluator：

| 角色 / 流程 | 对技术债的职责 | 接口动作 |
|------|----------------|----------|
| **Planner** | 无默认职责 | 不读取、不排期本文件，除非用户明确要求清理某个 TD-id |
| **Generator** | 无默认职责 | 不登记、不清理技术债；发现非阻塞问题最多在最终报告备注 |
| **Evaluator** | 无默认职责 | 不登记技术债；非阻塞坏味道不作为本 feature FAIL 理由 |
| **定时扫描** | 发现并登记 | 定期扫描代码/文档，把确认的问题 append 到本文件 |
| **人工审计** | 发现、归并、排期 | 合并重复条目，决定 open / scheduled / wontfix |

> 一句话：技术债可以用 harness 清理，但不由 harness 在普通 feature 流程中自动发现、登记或插队。

## 3. 债条目格式

append-only、**最新在上**（与 `docs/logging.md` 同款纪律）。每条一个 id `TD-NNN`（区别于 feature 的 `F1`）。状态变更就地改那一行，**不删除**历史条目。

**条目模板**（复制到下方分隔线正下方）：

```
### TD-NNN · <一句话标题>

- 状态：🔴 open ｜ 🟡 scheduled(<slug>) ｜ ✅ resolved(<commit/PR>) ｜ ⚪ wontfix(<理由>)
- 类别：重复代码 / 偏离规范 / 不一致命名 / 缺测试 / 文档漂移 / 可重构 / 其他
- 严重度：高 / 中 / 低
- 位置：<文件:行 或 模块/入口>
- 来源：定时扫描-代码 / 定时扫描-文档 / 人工审计 / 手动
- 登记：<YYYY-MM-DD> · 关联 <slug / feature-id / commit，无则 —>
- 说明：<是什么债、为何先搁置、清理时建议怎么做>
```

约定：

- **定时扫描入账**：扫描任务只 append 条目，不改业务代码。
- **排序**：由人工审计或专门维护任务按 `严重度` + 是否反复挡路排序。
- **清理闭环**：债被清掉时，把对应条目状态改成 ✅ resolved 并填 commit；在清理任务的 `plan.md` / commit message 里注明 `clears TD-NNN`。
- **不修也要交代**：决定不修的标 ⚪ wontfix 并写明理由，别让它一直挂在 open。

## 4. 独立定时扫描（设计，未落地）

对应 README「技术债清理」里「独立定时扫描、登记技术债或另起清理任务」的设想。本节是**设计描述，本次不配置实际任务**——落地时再按需接 hook / 定时任务。该扫描独立于 `/harness` 主循环运行。

- **触发**：低频定时（如每日 / 每周一次），或仓库空闲时由人手动发起。
- **范围**：
  - *代码库*：`scripts/` 与 `on_policy_distillation.sh` / `grpo.sh`（OPD 自有代码；**不扫** vendored 的 `verl/`、`LlamaFactory/`）——找重复、偏离规范、不一致命名、缺测试。
  - *文档库*：`docs/`、`README.md`——找过期描述、断链、与代码漂移的说明。
- **产物（两条路，按严重度分流）**：
  1. **轻量问题** → 直接往本文件 append open 条目（来源标 `定时扫描-*`），不打断当前工作。
  2. **独立、低风险、可一键验证的修复** → 生成独立清理任务建议；是否用 `/harness` 执行由人决定。
- **与 harness 的边界**：定时扫描只负责「发现 + 入账 / 起单建议」，不改写正在运行的 `features.json`，不要求 Planner/Generator/Evaluator 在普通 feature 流程中处理技术债。

## 5. 生命周期与归属

```
发现（定时扫描 / 人工审计 / 手动） → 🔴 open（登记到本文件）
   → 独立清理任务排期 → 🟡 scheduled(<slug 或任务名>)
   → 清理任务完成并验证 → ✅ resolved(<commit>)
   （或经评估不值得修 → ⚪ wontfix）
```

- 本文件**跨 slug、长期存在**，放在 `docs/exec-plans/` 根（与 `active/`、`completed/` 同级），不随单个 slug 归档。
- 与其他共享状态的关系：`features.json` 是单次需求的真相源；本文件是**跨需求**的债账；`docs/logging.md` 是时间线交接。技术债账本不参与普通 feature 的 Planner/Generator/Evaluator 状态流。

---

<!-- 在此分隔线正下方追加新条目，保持最新在上。 -->

### TD-001 · harness 流程契约仍有多处未固化

- 状态：🔴 open
- 类别：偏离规范 / 缺测试 / 文档漂移
- 严重度：中
- 位置：.claude/commands/harness.md / .claude/agents/*.md / docs/design-docs/harness.md
- 来源：手动
- 登记：2026-05-31 · 关联 harness-audit
- 说明：当前 harness 设计完整，但命令模板和 agent prompt 对 schema 校验、feedback append-only、提交归属、可恢复执行、GPU 验证分级、产物归档对账等约束仍有部分依赖人工执行；建议后续拆成可独立验收的小 feature 排期落地。
