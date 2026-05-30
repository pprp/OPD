# 技术债追踪（Tech Debt Tracker）

> 跨 slug、append-only 的**技术债登记簿**：记录那些「明知更好、却为聚焦当前 feature 而被**刻意推迟**」的改进，以及后台扫描发现的存量问题。它是 README「技术债清理」支柱与 `/harness` 三智能体编排的接口；机制总览见 `docs/design-docs/harness.md`。

## 1. 为什么需要它

harness 的几条铁律会**主动制造**技术债——这是设计使然，不是缺陷：

- **一次只做一个 feature** / Generator **不顺手改别的** → 路过的坏味道不能就地修；
- **Evaluator 只读、不 scope-creep** → 发现的非阻塞问题不能塞进本轮判 FAIL；
- **非侵入式**（不动 `verl/`、`LlamaFactory/`） → 一些本该上游修的问题只能先绕开；
- **3 轮未过的妥协** → 为通过验收而走的捷径。

这些被推迟的改进若没有落点，就会**丢失**——下一个全新上下文的 agent 根本不知道它们存在。本文件就是它们的落点：**登记是廉价、非阻塞的；清理走正常的 `/harness` 循环。** 把「发现」与「修复」解耦，既守住「一次只做一件事」，又不丢账。

债的两个来源：

| 来源 | 谁登记 | 典型内容 |
|------|--------|----------|
| **流程内债**（intrinsic） | 三智能体在 `/harness` 循环中 | 搁置的重构、非阻塞坏味道、为过验收的捷径 |
| **存量债**（standing） | 后台扫描 / 人工 | 重复代码、偏离规范、不一致命名、文档漂移 |

## 2. 与三智能体编排的融合（核心）

技术债追踪不是独立流程，而是**嵌在 Planner→Generator→Evaluator 循环的每个环节**：

| 角色 | 对技术债的职责 | 接口动作 |
|------|----------------|----------|
| **Planner** | 排期时**拉取** open 债 | 起手读本文件，把够格的 open 债作为 feature 写进 `features.json`（`category` 取 `infra`/`doc`/`eval`），在 `plan.md` 注明本次清理了哪些 TD-id |
| **Generator** | **登记**搁置项，绝不顺手改 | 实现单个 feature 时若发现路过的债，**不就地修**，而是在收尾时往本文件 append 一条；手上只做这一个 feature |
| **Evaluator** | **登记**非阻塞问题，而非判 FAIL | 只读复验时发现「不影响本 feature 达标、但确是债」的问题（重复/命名/缺测试），登记到本文件，**不**据此判 FAIL（避免把验收变成无限 scope creep） |
| **编排者（主线程）** | **汇总 + 收尾对账** | 一个 feature 通过后、写 `docs/logging.md` 前，确认本轮新增债已登记；3 轮未过的妥协登记为债后再交人决策 |
| **后台扫描**（见 §4） | **批量喂入**存量债 | 定期扫码库/文档库，把发现写进本文件，攒够一批由人发起一次 `/harness "清理 TD-xxx..xxx"` |

> 一句话：**Evaluator/Generator 负责「发现并登记」，Planner 负责「排期」，`/harness` 循环负责「清理」。** 债的清理本身也是一个个 Default-FAIL feature，同样要被独立验收——绝不绕过 Evaluator。

## 3. 债条目格式

append-only、**最新在上**（与 `docs/logging.md` 同款纪律）。每条一个 id `TD-NNN`（区别于 feature 的 `F1`）。状态变更就地改那一行，**不删除**历史条目。

**条目模板**（复制到下方分隔线正下方）：

```
### TD-NNN · <一句话标题>

- 状态：🔴 open ｜ 🟡 scheduled(<slug>) ｜ ✅ resolved(<commit/PR>) ｜ ⚪ wontfix(<理由>)
- 类别：重复代码 / 偏离规范 / 不一致命名 / 缺测试 / 文档漂移 / 可重构 / 其他
- 严重度：高 / 中 / 低
- 位置：<文件:行 或 模块/入口>
- 来源：generator 搁置 / evaluator 非阻塞 / planner 排期 / 后台扫描-代码 / 后台扫描-文档 / 手动
- 登记：<YYYY-MM-DD> · 关联 <slug / feature-id / commit，无则 —>
- 说明：<是什么债、为何先搁置、清理时建议怎么做>
```

约定：

- **Planner 拉单**：起手时 `grep "🔴 open" docs/exec-plans/tech-debt-tracker.md` 即得待排期清单。
- **排序**：按 `严重度` + 是否反复挡路；高危或反复挡路的优先排进下一轮。
- **清理闭环**：债被某 feature 清掉时，把对应条目状态改成 ✅ resolved 并填 commit；在该 feature 的 `plan.md` / commit message 里注明 `clears TD-NNN`。
- **不修也要交代**：决定不修的标 ⚪ wontfix 并写明理由，别让它一直挂在 open。

## 4. 后台扫描（设计，未落地）

对应 README「技术债清理」里「定期扫描、发现问题直接提 PR」的设想。本节是**设计描述，本次不配置实际任务**——落地时再按需接 hook / 定时任务。

- **触发**：低频定时（如每日 / 每周一次），或仓库空闲时由人手动发起。
- **范围**：
  - *代码库*：`scripts/` 与 `on_policy_distillation.sh` / `grpo.sh`（OPD 自有代码；**不扫** vendored 的 `verl/`、`LlamaFactory/`）——找重复、偏离规范、不一致命名、缺测试。
  - *文档库*：`docs/`、`README.md`——找过期描述、断链、与代码漂移的说明。
- **产物（两条路，按严重度分流）**：
  1. **轻量问题** → 直接往本文件 append open 条目（来源标 `后台扫描-*`），不打断当前工作；攒够一批后由人发起 `/harness` 批量清。
  2. **独立、低风险、可一键验证的修复** → 直接走 `/harness` 出一个小 PR（仍受 Evaluator 独立验收约束，**不绕过**三智能体）。
- **与 harness 的边界**：后台扫描只负责「发现 + 入账 / 起单」，**不自行合并**；所有改动一律经 Generator 实现、Evaluator 独立复验、人确认，守住「自己不给自己打分」。

## 5. 生命周期与归属

```
发现（generator / evaluator / 扫描 / 人） → 🔴 open（登记到本文件）
   → Planner 拉单 → 🟡 scheduled(<slug>)（进某个 active/<slug>/features.json）
   → /harness 清理 + Evaluator 验收 → ✅ resolved(<commit>)
   （或经评估不值得修 → ⚪ wontfix）
```

- 本文件**跨 slug、长期存在**，放在 `docs/exec-plans/` 根（与 `active/`、`completed/` 同级），不随单个 slug 归档。
- 与其他共享状态的关系：`features.json` 是单次需求的真相源；本文件是**跨需求**的债账；`docs/logging.md` 是时间线交接。三者互补，不重复。

---

<!-- 在此分隔线正下方追加新条目，保持最新在上。 -->

_（暂无技术债条目。）_
