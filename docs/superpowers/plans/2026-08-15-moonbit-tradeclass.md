# moonbit-tradeclass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable MoonBit library and CLI for version-aware trade classification concordances, with auditable mapping results, aggregation, fixtures, documentation, and reproducible CI.

**Architecture:** Keep a dependency-light core package for classification metadata, rules, graph traversal, confidence, and aggregation. Add a small command package for deterministic fixture/demo workflows; keep complete official datasets out of the repository and document source/licensing boundaries.

**Tech Stack:** MoonBit 0.10.3, Moon standard/core library, GitHub Actions, JSON/CSV-compatible text fixtures, Apache-2.0.

---

### Task 1: Repository contract and metadata

**Files:** `moon.mod`, `moon.pkg`, `.gitignore`, `LICENSE`, `README.md`, `CHANGELOG.md`, `NOTICE`, `docs/submission.md`

- [ ] Add module metadata, license, contribution/source notes, and competition-facing README.
- [ ] Document public API boundary, non-inclusion of proprietary classification datasets, and roadmap.
- [ ] Commit as `chore: initialize tradeclass repository`.

### Task 2: Domain model

**Files:** `src/model.mbt`, `src/moon.pkg`, `src/model_test.mbt`

- [ ] Define classification systems, versions, product codes, mapping confidence, rules, and result types.
- [ ] Add validation for empty codes, invalid weights, and malformed rule targets.
- [ ] Write tests for model construction and validation, then run `moon test`.
- [ ] Commit as `feat: add classification domain model`.

### Task 3: Concordance graph and version conversion

**Files:** `src/concordance.mbt`, `src/convert.mbt`, `src/concordance_test.mbt`

- [ ] Implement one-to-one, one-to-many, many-to-one, weighted rules and transitive traversal with cycle protection.
- [ ] Preserve exact/approximate/unmappable status and explanatory reasons.
- [ ] Cover additions, deletions, splits, merges, cycles, and missing mappings with fixture-backed tests.
- [ ] Commit the graph and conversion increments separately.

### Task 4: Tree aggregation and interchange formats

**Files:** `src/tree.mbt`, `src/aggregate.mbt`, `src/format.mbt`, `fixtures/sample_rules.csv`, `fixtures/sample_trade.csv`, tests

- [ ] Implement parent/child lookup and aggregation by product level, country, and year.
- [ ] Provide a minimal deterministic CSV parser/exporter and JSON-shaped documentation examples without embedding official datasets.
- [ ] Test weighted aggregation and rejected records.
- [ ] Commit model, aggregation, and fixture/documentation increments separately.

### Task 5: CLI and examples

**Files:** `cmd/moonbit-tradeclass/main.mbt`, `cmd/moonbit-tradeclass/moon.pkg`, `examples/`, `docs/quickstart.md`

- [ ] Implement `map` and `aggregate` demo commands against user-provided CSV paths, with readable error output.
- [ ] Add runnable examples and API usage snippets.
- [ ] Commit as `feat: add tradeclass command line demo`.

### Task 6: CI, generated interfaces, and release hygiene

**Files:** `.github/workflows/test.yml`, `.github/workflows/check.yml`, `pkg.generated.mbti`, `src/pkg.generated.mbti`, `CONTRIBUTING.md`

- [ ] Add MoonBit 0.10.3-compatible CI modeled on MoonBit community templates: format deny-warn, check deny-warn, info diff, test, native test, and CLI check.
- [ ] Generate and review public interface files; ensure clean formatting and no warnings.
- [ ] Commit CI and generated-interface changes separately.

### Task 7: Verification, history, and delivery

- [ ] Run `moon fmt --deny-warn`, `moon info --deny-warn`, `moon check --deny-warn`, `moon test --deny-warn`, native checks, and CLI checks.
- [ ] Review source line count, license, README, origin, default branch, author identity, and commit count.
- [ ] Make at least 11 meaningful commits, then create and push the GitHub repository using the active `gh` account only.
- [ ] Write a one-page Chinese project proposal at `docs/project-proposal.md` and record the final validation evidence.

