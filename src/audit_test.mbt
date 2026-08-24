///|
fn audit_valid_report() -> TradeImportReport {
  import_trade_csv(
    "code,country,year,amount\n0101,CN,2022,100\n0102,US,2023,200\n",
    default_trade_import_options(),
  )
}

///|
test "clean imports receive a passing audit" {
  let report = audit_trade_report(audit_valid_report(), default_audit_policy())
  assert_true(!audit_has_errors(report))
  assert_true(audit_is_ready(report, 90.0))
  assert_eq(audit_checked_rows(report), 2)
  assert_eq(audit_accepted_rows(report), 2)
  assert_eq(audit_error_count(report), 0)
  assert_eq(audit_warning_count(report), 0)
  assert_eq(audit_country_coverage(audit_valid_report()), 2)
  assert_eq(audit_year_coverage(audit_valid_report()), 2)
  assert_eq(audit_duplicate_count(audit_valid_report()), 0)
  assert_true(audit_summary(report).contains("score="))
  assert_true(audit_report_markdown(report).contains("Data quality audit"))
  assert_true(audit_report_csv(report).contains("healthy_dataset"))
}

///|
test "audits retain invalid import reasons" {
  let invalid = import_trade_csv(
    "code,country,year,amount\n0101,C,2022,-4\n0101,CN,2022,5\n",
    default_trade_import_options(),
  )
  let report = audit_trade_report(invalid, default_audit_policy())
  assert_true(audit_has_errors(report))
  assert_true(audit_error_count(report) > 0)
  assert_true(!audit_is_ready(report, 90.0))
  let lines = audit_finding_lines(report)
  assert_true(lines.length() > 0)
  assert_true(lines[0].contains("invalid_country"))
}

///|
test "record audits catch duplicates and policy violations" {
  let records = [
    trade_record("CN", 2022, "0101", 10.0),
    trade_record("CN", 2022, "0101", 11.0),
    trade_record("X", 1800, "", -2.0),
  ]
  let policy = audit_policy(0, 1.0, 1900, 2100, 2, true, true)
  let report = audit_records(records, policy)
  assert_true(audit_has_errors(report))
  assert_true(audit_duplicate_count(audit_valid_report()) == 0)
  assert_true(audit_score_value(report) < 100.0)
}

///|
test "benchmark concordance passes rule audit" {
  let book = benchmark_concordance()
  let report = audit_rules(book.rules, default_audit_policy())
  assert_true(!audit_has_errors(report))
  assert_true(audit_is_ready(report, 90.0))
  assert_eq(audit_checked_rows(report), 1600)
  assert_eq(audit_accepted_rows(report), 1600)
  assert_eq(audit_rule_weight(book.rules[0]), 1.0)
  let coverage = audit_rule_coverage(["HS00", "missing"], book)
  assert_true(audit_warning_count(coverage) > 0)
  assert_eq(audit_checked_rows(coverage), 2)
}

///|
test "rule audit identifies unbalanced rules" {
  let unbalanced = concordance_rule(
    "unbalanced",
    [mapping_target("target", 0.4)],
    exact_confidence(),
    "bad",
  ) catch {
    err => abort(err.to_string())
  }
  let report = audit_rules([unbalanced], default_audit_policy())
  assert_true(audit_has_errors(report))
  assert_true(audit_report_csv(report).contains("unbalanced_rule"))
}

///|
test "audit combination recomputes score and counts" {
  let data = audit_trade_report(audit_valid_report(), default_audit_policy())
  let rules = audit_rules(benchmark_concordance().rules, default_audit_policy())
  let combined = audit_combine(data, rules)
  assert_eq(audit_checked_rows(combined), 1602)
  assert_eq(audit_accepted_rows(combined), 1602)
  assert_true(audit_score_value(combined) <= audit_score_value(data))
  assert_true(audit_finding_count(combined) > 0)
  assert_eq(audit_findings(combined).length(), audit_finding_count(combined))
}
