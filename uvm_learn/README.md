# uvm_learn

《UVM实战》（张强）的学习记录，边读边搭，代码都在 Rocky VM + VCS（UVM 1.2）上实际跑通过。

## 目录

- `PLAN.md` — 学习总计划（项目驱动，目标 10–15 个有效日达到可投递实习水平，活文档）
- `ch2/` — 第 2 章验证平台（代码 + README；学习笔记整合为 `ch2_notes.md`，单份旧笔记仍保留）
- `journal/` — 学习日报，一天一篇，文件名 `YYYY-MM-DD.md`

## 环境

- 仿真：VCS W-2024.09（UVM 1.2），跑在 VMware 的 Rocky Linux 8.10 里
- 代码位置：VM `~/workspace/uvm_learn/`，本地这份是镜像
- 流程：本地改代码 → scp 到 VM → `make comp && make run` → 拉回日志

书是 UVM 1.1d，VCS 用的是 1.2，差异都记在各章笔记和日报里。
