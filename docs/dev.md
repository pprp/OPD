# 开发规范

## 工作流程

- **每次只做一件事情**：聚焦单一任务，避免一次铺开多个改动。
- **开工前读日志**：开始前阅读 @docs/logging.md，掌握已有进度与注意事项。
- **收工后写日志**：结束时按 @docs/logging.md 中的模板追加本次进展。
- **测试驱动开发**：先跑 smoke test，确认链路可跑通后，再做大规模实验。
- **非平凡任务用 harness**：较大的改动用 `/harness <需求>` 跑 Planner→Generator→Evaluator 三智能体循环（自动拆解、实现、独立验收、写日志）；机制见 @docs/design-docs/harness.md。
- **技术债即时登记**：发现但本次不修的重复代码 / 偏离规范 / 不一致命名等，登记到 @docs/exec-plans/tech-debt-tracker.md，**不要顺手扩大改动范围**；积累的债由 `/harness` 排期清理。

## 上下文与文档纪律

- **按需读取**：只读取与当前任务相关的文档。
- **渐进式披露**：不要一次性加载全部内容。
- **就近原则**：信息冲突时，以更具体的文档为准。

## 代码质量与提交

- **提交前过 linter**：本地依次执行并通过后，再添加为 commit：

  ```bash
  make format
  make lint
  pre-commit run --all-files
  ```

  本地 lint 仅覆盖 OPD 自有代码（`scripts/` 与 `on_policy_distillation.sh`、`grpo.sh`）；vendored 的 `LlamaFactory/`、`verl/` 沿用各自上游工具。

- **非侵入式修改**：尽量不改动 vendored 的 `LlamaFactory/` 与 `verl/`（除非不得不）。

> 硬件、conda 环境与关键入口见 @docs/env.md。
