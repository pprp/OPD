# 开发日志（Worklog）

> 用途：跨工作会话的**交接记录**。开工前读最新一条掌握现状，收工后在顶部追加一条。
> 规则：**最新在上**；一次只记一件事；字段无内容填「—」。
> 状态图例：✅ 完成 ｜ 🚧 进行中 ｜ ⛔ 阻塞（详情写进「需人决策」）

**条目模板**（复制到下方分隔线正下方，保持最新在上）：

```
## YYYY-MM-DD · <一句话主题>

- 状态：✅ 完成 / 🚧 进行中 / ⛔ 阻塞
- 做了什么：<本次具体动作，可分点>
- 涉及：<改动或查看的文件、入口，用 / 分隔>
- 注意：<坑、约束、未验证项；无则 —>
- 下一步：<下次开工第一件事；无则 —>
- 需人决策：否 / 是（<具体待决策问题>）
```

---

## 2026-05-31 · 强化 harness feature 与恢复协议

- 状态：✅ 完成
- 做了什么：按 Anthropic long-running agent harness 原语重写 `features.json` 构造约束；新增 per-slug `progress.md` 恢复机制；将技术债治理从 Planner/Generator/Evaluator 主循环中拆出，改为独立定时扫描 / 人工排期
- 涉及：.claude/commands/harness.md / .claude/agents/planner.md / .claude/agents/generator.md / .claude/agents/evaluator.md / docs/design-docs/harness.md / docs/exec-plans/tech-debt-tracker.md / docs/dev.md / README.md
- 注意：仅修改文档与 Claude prompt；未实际运行 `/harness` 三智能体任务
- 下一步：为 `features.json` / `progress.md` 加脚本级 schema 校验与 append-only 检查
- 需人决策：否

## 2026-05-31 · 审计 harness 改进空间

- 状态：✅ 完成
- 做了什么：检查 `.claude/commands/harness.md`、三角色 agent prompt、harness 设计文档与技术债接口，梳理当前 harness 可改进点
- 涉及：.claude/commands/harness.md / .claude/agents/planner.md / .claude/agents/generator.md / .claude/agents/evaluator.md / docs/design-docs/harness.md / docs/exec-plans/tech-debt-tracker.md
- 注意：未运行真实 `/harness` 任务；结论基于静态审计与文档/配置一致性检查
- 下一步：将 TD-001 拆成可独立验收的 harness hardening features
- 需人决策：否

## 2026-05-30 · 梳理 OPD 主线与 verl 接入点

- 状态：✅ 完成
- 做了什么：定位入口脚本、OPD reward/advantage/loss 关键链路、SFT rollout 与独立评测脚本
- 涉及：on_policy_distillation.sh / grpo.sh / scripts/val/eval/
- 注意：未修改训练代码
- 下一步：跑 smoke test 验证链路
- 需人决策：否
