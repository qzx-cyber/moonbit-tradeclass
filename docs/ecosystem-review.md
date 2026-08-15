# Ecosystem review

检索日期：2026-08-15。

在 Mooncakes.io 及其公开包索引中，按 `concordance`、`HS code`、`SITC`、`BEC`、`NAICS`、`NACE`、`trade classification`、`商品分类映射` 逐项检索，未发现以国际贸易分类映射为核心的现成项目。DataFrame 和 OLAP 相关项目属于通用数据处理/聚合底层能力，与本项目的分类版本、规则可追溯和映射置信度边界不同，因此暂不作为重复项目。

本项目仍避免把完整官方数据库放入仓库，并把算法、夹具、来源和许可证分开记录。后续若发布 Mooncakes 包，将优先拆分为核心模型、concordance、aggregation 和 CLI 四个可独立复用的包，发布前再次检索名称和功能重合度。

比赛资料：

- [8 月黑客松活动说明](https://bxup9uklfcb.feishu.cn/wiki/KNrVwEVFziPHiGkQtwhc6w3gndd)
- [参考 CLI 检查 workflow](https://github.com/PaiGack/moonbitlang-OSC2026/blob/main/.github/workflows/test.yml)
- [MoonBit 社区 workflow templates](https://github.com/moonbit-community/.github/tree/main/workflow-templates)
