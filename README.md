# moonbit-tradeclass

MoonBit 国际贸易商品分类映射与版本转换库。项目面向贸易统计、海关分析和经济研究，提供分类体系元数据、版本差异、可追溯 concordance 规则、带权映射与聚合基础能力。

## 当前版本

核心库已经可以表达 HS、SITC、BEC、NAICS、NACE 等体系，支持一对一、一对多、多对一、带权重映射，并对精确、近似、不可映射结果保留原因。映射图具备循环保护，聚合器按国家、年份和产品代码组合汇总金额。

```mbt nocheck
let hs = classification_system("HS", "Harmonized System")
let version = classification_version(hs, "2022", 2022)
let item = product_code(version, "0101", "Live horses", 4, active_code_state(), None)
let rule = concordance_rule(
  "0101",
  [mapping_target("010121", 0.7), mapping_target("010129", 0.3)],
  exact_confidence(),
  "local fixture",
)
let result = map_code(concordance([rule]), item.code)
```

## 设计边界

本仓库只提供数据模型、映射算法、质量状态和自制小型夹具，不打包 HS、SITC、BEC、NAICS 或 NACE 的完整官方商品数据库。官方原始分类数据的获取、再分发与许可证由使用者自行确认；本项目代码与映射算法以 Apache-2.0 发布。`NOTICE` 和 `docs/data-sources.md` 记录来源边界。

## 验证

```text
moon fmt --check
moon info
moon check --deny-warn
moon test --deny-warn
moon check --target native --deny-warn
moon test --target native --deny-warn
```

## 路线图

下一步是完善 JSON/CSV 读写、版本差异报告、代码自动迁移、映射质量评估、WASM 数据分析组件和独立的 `moonbit-tradeclass map` / `aggregate` CLI。

## 竞赛信息

项目标识：`moonbit-tradeclass`。这是 2026 年 8 月 MoonBit 黑客松参赛项目，申报材料见 [docs/project-proposal.md](docs/project-proposal.md)，开发计划见 [docs/superpowers/plans/2026-08-15-moonbit-tradeclass.md](docs/superpowers/plans/2026-08-15-moonbit-tradeclass.md)。
