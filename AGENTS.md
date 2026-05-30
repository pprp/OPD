# OPD 项目

探索 OPD（on-policy distillation）设计，复现 / 证伪论文《Rethinking On-Policy Distillation》与 `README.md` 的结论。

> 文档总入口。按「渐进式披露」：先用「何时读」判断该展开哪篇，不要一次性全读；信息冲突时以更具体的文档为准。

| 文档 | 何时读 |
|------|--------|
| [docs/dev.md](docs/dev.md) | **每次开工**——开发规范：一次一件事 / 测试驱动 / 非侵入式改 vendored / 提交前过 lint |
| [docs/logging.md](docs/logging.md) | 开工读最新进展；**收工**按模板在顶部追加一条 |
| [docs/env.md](docs/env.md) | 配环境、找入口脚本、确认显存约束（8×5090 32GB） |
| [docs/design-docs/opd-method.md](docs/design-docs/opd-method.md) | 读懂 / 改动 OPD 的 reward·advantage·loss 链路 |
| [docs/design-docs/experiments.md](docs/design-docs/experiments.md) | 设计 / 登记 / 执行实验 |
| [docs/design-docs/harness.md](docs/design-docs/harness.md) | 跑或调 `/harness` 三智能体流程 |
| [docs/exec-plans/tech-debt-tracker.md](docs/exec-plans/tech-debt-tracker.md) | 登记「本次不修」的技术债；Planner 排期拉单 |

`README.md` 有各入口完整参数；`docs/exec-plans/{active,completed}/` 是 `/harness` 运行产物。
