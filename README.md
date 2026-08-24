# moonbit-tradeclass

[![CI](https://github.com/qzx-cyber/moonbit-tradeclass/actions/workflows/test.yml/badge.svg)](https://github.com/qzx-cyber/moonbit-tradeclass/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

面向贸易统计、海关分析和经济研究的 MoonBit 分类映射库。它把分类体系元数据、版本差异、可追溯 concordance 规则、带权映射、质量审计和聚合分析组合成一个可复用的纯数据处理内核。

## 核心能力

- 表达 HS、SITC、BEC、NAICS、NACE 等分类体系及其版本、层级和代码状态。
- 支持一对一、一对多、多对一、带权重和跨版本链式映射，并对循环、缺失和不可映射结果保留原因。
- 提供代码规范化、目录查询、父子关系、版本差异报告和规则质量审计。
- 提供按国家、年份和产品代码的确定性聚合，以及均值、分位数、份额和集中度等基础统计。
- 内置可复现的项目自有合成基准工作负载，用于验证吞吐、权重和边界行为；不冒充官方分类数据库。

## 快速开始

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

```text
moon check --deny-warn
moon test --deny-warn
moon run cmd/moonbit-tradeclass --target native
```

## CLI

命令行演示使用库内的许可清晰的小型工作负载，适合确认工具链、映射链和基准数据是否可用：

```text
moon run cmd/moonbit-tradeclass --target native
```

CLI 输出包含基准记录数、映射规则数、场景规模和质量摘要。生产数据应由调用方在确认来源许可后接入库 API；完整 CSV/JSON 适配器属于上层应用边界。

## 架构

```text
model       领域对象、状态和构造校验
normalization 代码规范化、层级和前缀操作
registry    分类体系、版本和产品目录
concordance 映射图、权重传播和循环保护
aggregate   贸易记录确定性聚合
analytics   描述统计、份额、变化和窗口计算
diff        版本代码新增、删除和元数据变更
quality     规则、目录和权重质量审计
benchmark.mbt 可复现的合成基准生成器
cmd/        可执行演示
```

所有核心模块仅依赖 MoonBit 标准库，数组处理保持确定性，便于 WASM、native 和后续 Mooncakes 依赖复用。

## 基准

仓库内的 `benchmark.mbt` 生成 1,000 条记录、2,000 个映射场景、1,600 条带权规则和 700 个阈值配置。它们是项目自有、可复现的合成工作负载，目的是让每次 CI 和本地运行使用同一输入；它们不包含也不替代 HS、SITC 等官方完整数据。

本地可用以下命令测量真实运行时间，并把结果记录到发布说明或 CI 工件中：

```powershell
Measure-Command { moon run cmd/moonbit-tradeclass --target native }
```

## 测试

测试覆盖模型构造、负权重、空规则、拆分、桥接、合并、循环、缺失映射、目录一致性、规范化边界、版本差异、聚合和基准数据不变量。规范化边界测试使用参数化输入覆盖多种空白、分隔符、大小写和层级长度。

```text
moon fmt --check
moon info
moon check --deny-warn
moon test --deny-warn
moon check --target native --deny-warn
moon test --target native --deny-warn
```

## CI

GitHub Actions 使用 MoonBit stable 安装器，并强制 Moonc `>= v0.10.9`，执行格式检查、公共接口差异检查、全目标类型检查和测试，以及 CLI native smoke test。工作流文件位于 `.github/workflows/test.yml`，每次 push 和 pull request 自动运行。

## 数据与许可证边界

本仓库只提供数据模型、映射算法、质量状态和自制小型夹具，不打包 HS、SITC、BEC、NAICS 或 NACE 的完整官方商品数据库。官方原始分类数据的获取、再分发与许可证由使用者自行确认；本项目代码与映射算法以 Apache-2.0 发布。`NOTICE` 和 `docs/data-sources.md` 记录来源边界。

## 许可证

代码以 Apache License 2.0 发布，详见 [LICENSE](LICENSE)。官方分类原始数据不随本仓库分发；使用者需要自行核对来源、版本和再分发许可。贡献方式见 [CONTRIBUTING.md](CONTRIBUTING.md)，变更记录见 [CHANGELOG.md](CHANGELOG.md)。
