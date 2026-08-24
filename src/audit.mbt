///|
/// Deterministic data-quality audits for scheduled imports and concordance
/// releases. An audit is deliberately separate from parsing: the parser says
/// whether a row can be read, while the audit says whether the resulting
/// dataset is safe to publish or use in a downstream report.

///|
pub enum AuditSeverity {
  AuditInfo
  AuditWarning
  AuditError
} derive(Debug, Eq)

///|
pub enum AuditCode {
  EmptyDataset
  RejectedInput
  LowAcceptance
  InvalidCodeRows
  InvalidCountryRows
  InvalidYearRows
  InvalidAmountRows
  NegativeAmountRows
  DuplicateRecords
  CountryCoverage
  YearCoverage
  EmptyRule
  UnbalancedRule
  DuplicateRuleSource
  UnmappableCode
  HealthyDataset
} derive(Debug, Eq)

///|
pub struct AuditFinding {
  severity : AuditSeverity
  code : AuditCode
  message : String
  mut count : Int
} derive(Debug, Eq)

///|
pub struct AuditPolicy {
  maximum_rejected : Int
  minimum_acceptance_ratio : Double
  minimum_year : Int
  maximum_year : Int
  minimum_country_count : Int
  require_nonnegative_amounts : Bool
  require_balanced_rules : Bool
} derive(Debug, Eq)

///|
pub fn audit_policy(
  maximum_rejected : Int,
  minimum_acceptance_ratio : Double,
  minimum_year : Int,
  maximum_year : Int,
  minimum_country_count : Int,
  require_nonnegative_amounts : Bool,
  require_balanced_rules : Bool,
) -> AuditPolicy {
  {
    maximum_rejected,
    minimum_acceptance_ratio,
    minimum_year,
    maximum_year,
    minimum_country_count,
    require_nonnegative_amounts,
    require_balanced_rules,
  }
}

///|
pub fn default_audit_policy() -> AuditPolicy {
  audit_policy(0, 1.0, 1900, 2100, 1, true, true)
}

///|
pub struct AuditReport {
  findings : Array[AuditFinding]
  checked_rows : Int
  accepted_rows : Int
  score : Double
} derive(Debug, Eq)

///|
pub fn audit_finding(
  severity : AuditSeverity,
  code : AuditCode,
  message : String,
  count : Int,
) -> AuditFinding {
  { severity, code, message, count }
}

///|
fn audit_add_finding(
  findings : Array[AuditFinding],
  severity : AuditSeverity,
  code : AuditCode,
  message : String,
  count : Int,
) -> Unit {
  if count <= 0 {
    return
  }
  for finding in findings {
    if finding.code == code {
      finding.count += count
      return
    }
  }
  findings.push(audit_finding(severity, code, message, count))
}

///|
fn audit_import_code(kind : ImportIssueKind) -> AuditCode {
  match kind {
    MissingField | InvalidCode => InvalidCodeRows
    InvalidCountry => InvalidCountryRows
    InvalidYear => InvalidYearRows
    InvalidAmount => InvalidAmountRows
    NegativeAmount => NegativeAmountRows
    DuplicateRecord => DuplicateRecords
    InvalidWeight | InvalidConfidence | InvalidRule => EmptyRule
  }
}

///|
fn audit_import_severity(kind : ImportIssueKind) -> AuditSeverity {
  match kind {
    DuplicateRecord => AuditWarning
    _ => AuditError
  }
}

///|
fn audit_code_name(code : AuditCode) -> String {
  match code {
    EmptyDataset => "empty_dataset"
    RejectedInput => "rejected_input"
    LowAcceptance => "low_acceptance"
    InvalidCodeRows => "invalid_code_rows"
    InvalidCountryRows => "invalid_country_rows"
    InvalidYearRows => "invalid_year_rows"
    InvalidAmountRows => "invalid_amount_rows"
    NegativeAmountRows => "negative_amount_rows"
    DuplicateRecords => "duplicate_records"
    CountryCoverage => "country_coverage"
    YearCoverage => "year_coverage"
    EmptyRule => "empty_rule"
    UnbalancedRule => "unbalanced_rule"
    DuplicateRuleSource => "duplicate_rule_source"
    UnmappableCode => "unmappable_code"
    HealthyDataset => "healthy_dataset"
  }
}

///|
fn audit_severity_name(severity : AuditSeverity) -> String {
  match severity {
    AuditInfo => "info"
    AuditWarning => "warning"
    AuditError => "error"
  }
}

///|
fn audit_score(findings : Array[AuditFinding]) -> Double {
  let mut score = 100.0
  for finding in findings {
    match finding.severity {
      AuditInfo => score -= finding.count.to_double() * 0.5
      AuditWarning => score -= finding.count.to_double() * 5.0
      AuditError => score -= finding.count.to_double() * 20.0
    }
  }
  if score < 0.0 {
    0.0
  } else {
    score
  }
}

///|
fn audit_distinct_countries(records : Array[TradeRecord]) -> Array[String] {
  let countries : Array[String] = []
  for record in records {
    if !countries.contains(record.country) {
      countries.push(record.country)
    }
  }
  sort_codes_lexical(countries)
}

///|
fn audit_distinct_years(records : Array[TradeRecord]) -> Array[Int] {
  let years : Array[Int] = []
  for record in records {
    if !years.contains(record.year) {
      years.push(record.year)
    }
  }
  let mut i = 0
  while i < years.length() {
    let mut j = i + 1
    while j < years.length() {
      if years[j] < years[i] {
        let value = years[i]
        years[i] = years[j]
        years[j] = value
      }
      j += 1
    }
    i += 1
  }
  years
}

///|
fn audit_duplicate_records(records : Array[TradeRecord]) -> Int {
  let seen : Array[String] = []
  let mut duplicates = 0
  for record in records {
    let key = import_duplicate_key(record)
    if seen.contains(key) {
      duplicates += 1
    } else {
      seen.push(key)
    }
  }
  duplicates
}

///|
fn audit_record_range_issues(
  records : Array[TradeRecord],
  policy : AuditPolicy,
  findings : Array[AuditFinding],
) -> Unit {
  let mut invalid_years = 0
  let mut invalid_countries = 0
  let mut negative_amounts = 0
  let mut invalid_codes = 0
  for record in records {
    if record.year < policy.minimum_year || record.year > policy.maximum_year {
      invalid_years += 1
    }
    if !import_country_is_plausible(record.country) {
      invalid_countries += 1
    }
    if record.code == "" {
      invalid_codes += 1
    }
    if policy.require_nonnegative_amounts && record.amount < 0.0 {
      negative_amounts += 1
    }
  }
  audit_add_finding(
    findings,
    AuditError,
    InvalidYearRows,
    "records fall outside the configured year range",
    invalid_years,
  )
  audit_add_finding(
    findings,
    AuditError,
    InvalidCountryRows,
    "records contain invalid country identifiers",
    invalid_countries,
  )
  audit_add_finding(
    findings,
    AuditError,
    InvalidCodeRows,
    "records contain empty product codes",
    invalid_codes,
  )
  audit_add_finding(
    findings,
    AuditError,
    NegativeAmountRows,
    "records contain amounts forbidden by policy",
    negative_amounts,
  )
}

///|
pub fn audit_trade_report(
  report : TradeImportReport,
  policy : AuditPolicy,
) -> AuditReport {
  let findings : Array[AuditFinding] = []
  let records = report.records
  if records.is_empty() {
    audit_add_finding(
      findings,
      AuditError,
      EmptyDataset,
      "the import contains no accepted records",
      1,
    )
  }
  for issue in report.issues {
    audit_add_finding(
      findings,
      audit_import_severity(issue.kind),
      audit_import_code(issue.kind),
      issue.message,
      1,
    )
  }
  if report.rejected > policy.maximum_rejected {
    audit_add_finding(
      findings,
      AuditError,
      RejectedInput,
      "rejected rows exceed the import policy",
      report.rejected - policy.maximum_rejected,
    )
  }
  let acceptance = import_acceptance_ratio(report)
  if acceptance < policy.minimum_acceptance_ratio {
    audit_add_finding(
      findings,
      AuditError,
      LowAcceptance,
      "accepted row ratio is below the release policy",
      1,
    )
  }
  audit_record_range_issues(records, policy, findings)
  let duplicates = audit_duplicate_records(records)
  audit_add_finding(
    findings,
    AuditWarning,
    DuplicateRecords,
    "duplicate record keys were found in accepted data",
    duplicates,
  )
  let countries = audit_distinct_countries(records)
  if countries.length() < policy.minimum_country_count {
    audit_add_finding(
      findings,
      AuditWarning,
      CountryCoverage,
      "country coverage is below the configured minimum",
      policy.minimum_country_count - countries.length(),
    )
  }
  let years = audit_distinct_years(records)
  if years.is_empty() {
    audit_add_finding(
      findings,
      AuditWarning,
      YearCoverage,
      "no year coverage is available",
      1,
    )
  }
  if findings.is_empty() {
    audit_add_finding(
      findings,
      AuditInfo,
      HealthyDataset,
      "dataset satisfies the configured quality policy",
      1,
    )
  }
  {
    findings,
    checked_rows: report.input_rows,
    accepted_rows: report.accepted,
    score: audit_score(findings),
  }
}

///|
pub fn audit_records(
  records : Array[TradeRecord],
  policy : AuditPolicy,
) -> AuditReport {
  let table = records_to_csv(records)
  let report = import_trade_table(table, default_trade_import_options())
  audit_trade_report(report, policy)
}

///|
fn audit_rule_weight_total(rule : ConcordanceRule) -> Double {
  let mut total = 0.0
  for target in rule.to {
    total += target.weight
  }
  total
}

///|
fn audit_rule_source_count(
  rules : Array[ConcordanceRule],
  source : String,
) -> Int {
  let mut count = 0
  for rule in rules {
    if rule.from == source {
      count += 1
    }
  }
  count
}

///|
pub fn audit_rules(
  rules : Array[ConcordanceRule],
  policy : AuditPolicy,
) -> AuditReport {
  let findings : Array[AuditFinding] = []
  if rules.is_empty() {
    audit_add_finding(
      findings,
      AuditError,
      EmptyRule,
      "the concordance contains no rules",
      1,
    )
  }
  let mut empty_rules = 0
  let mut unbalanced_rules = 0
  let mut duplicate_sources = 0
  for rule in rules {
    if rule.to.is_empty() && rule.confidence != Unmappable {
      empty_rules += 1
    }
    let total = audit_rule_weight_total(rule)
    if policy.require_balanced_rules &&
      !rule.to.is_empty() &&
      (total < 0.999 || total > 1.001) {
      unbalanced_rules += 1
    }
    if audit_rule_source_count(rules, rule.from) > 1 {
      duplicate_sources += 1
    }
  }
  audit_add_finding(
    findings,
    AuditError,
    EmptyRule,
    "rules have no usable targets",
    empty_rules,
  )
  audit_add_finding(
    findings,
    AuditError,
    UnbalancedRule,
    "rule target weights do not sum to one",
    unbalanced_rules,
  )
  audit_add_finding(
    findings,
    AuditWarning,
    DuplicateRuleSource,
    "multiple rules share the same source code",
    duplicate_sources,
  )
  if findings.is_empty() {
    audit_add_finding(
      findings,
      AuditInfo,
      HealthyDataset,
      "concordance rules satisfy the configured quality policy",
      1,
    )
  }
  {
    findings,
    checked_rows: rules.length(),
    accepted_rows: rules.length() - empty_rules - unbalanced_rules,
    score: audit_score(findings),
  }
}

///|
pub fn audit_rule_coverage(
  codes : Array[String],
  book : Concordance,
) -> AuditReport {
  let findings : Array[AuditFinding] = []
  let mut unmappable = 0
  for code in codes {
    let result = map_code(book, code)
    if result.confidence == Unmappable {
      unmappable += 1
    }
  }
  audit_add_finding(
    findings,
    AuditWarning,
    UnmappableCode,
    "input codes have no usable concordance mapping",
    unmappable,
  )
  if findings.is_empty() {
    audit_add_finding(
      findings,
      AuditInfo,
      HealthyDataset,
      "all input codes have a usable mapping",
      1,
    )
  }
  {
    findings,
    checked_rows: codes.length(),
    accepted_rows: codes.length() - unmappable,
    score: audit_score(findings),
  }
}

///|
pub fn audit_combine(left : AuditReport, right : AuditReport) -> AuditReport {
  let findings : Array[AuditFinding] = []
  for finding in left.findings {
    audit_add_finding(
      findings,
      finding.severity,
      finding.code,
      finding.message,
      finding.count,
    )
  }
  for finding in right.findings {
    audit_add_finding(
      findings,
      finding.severity,
      finding.code,
      finding.message,
      finding.count,
    )
  }
  {
    findings,
    checked_rows: left.checked_rows + right.checked_rows,
    accepted_rows: left.accepted_rows + right.accepted_rows,
    score: audit_score(findings),
  }
}

///|
pub fn audit_findings(report : AuditReport) -> Array[AuditFinding] {
  report.findings.copy()
}

///|
pub fn audit_checked_rows(report : AuditReport) -> Int {
  report.checked_rows
}

///|
pub fn audit_accepted_rows(report : AuditReport) -> Int {
  report.accepted_rows
}

///|
pub fn audit_score_value(report : AuditReport) -> Double {
  report.score
}

///|
pub fn audit_finding_count(report : AuditReport) -> Int {
  report.findings.length()
}

///|
pub fn audit_error_count(report : AuditReport) -> Int {
  let mut count = 0
  for finding in report.findings {
    if finding.severity == AuditError {
      count += finding.count
    }
  }
  count
}

///|
pub fn audit_warning_count(report : AuditReport) -> Int {
  let mut count = 0
  for finding in report.findings {
    if finding.severity == AuditWarning {
      count += finding.count
    }
  }
  count
}

///|
pub fn audit_has_errors(report : AuditReport) -> Bool {
  audit_error_count(report) > 0
}

///|
pub fn audit_is_ready(report : AuditReport, minimum_score : Double) -> Bool {
  !audit_has_errors(report) && report.score >= minimum_score
}

///|
pub fn audit_finding_lines(report : AuditReport) -> Array[String] {
  let lines : Array[String] = []
  for finding in report.findings {
    lines.push(
      "[" +
      audit_severity_name(finding.severity) +
      "] " +
      audit_code_name(finding.code) +
      " x" +
      finding.count.to_string() +
      ": " +
      finding.message,
    )
  }
  lines
}

///|
pub fn audit_summary(report : AuditReport) -> String {
  "checked=" +
  report.checked_rows.to_string() +
  ", accepted=" +
  report.accepted_rows.to_string() +
  ", findings=" +
  report.findings.length().to_string() +
  ", errors=" +
  audit_error_count(report).to_string() +
  ", warnings=" +
  audit_warning_count(report).to_string() +
  ", score=" +
  report.score.to_string()
}

///|
pub fn audit_report_markdown(report : AuditReport) -> String {
  let builder = StringBuilder()
  builder.write_string("## Data quality audit\n\n")
  builder.write_string(
    "- Checked rows: " + report.checked_rows.to_string() + "\n",
  )
  builder.write_string(
    "- Accepted rows: " + report.accepted_rows.to_string() + "\n",
  )
  builder.write_string("- Score: " + report.score.to_string() + "\n")
  builder.write_string("\n### Findings\n\n")
  for line in audit_finding_lines(report) {
    builder.write_string("- " + line + "\n")
  }
  builder.to_string()
}

///|
pub fn audit_report_csv(report : AuditReport) -> String {
  let rows : Array[Array[String]] = []
  for finding in report.findings {
    rows.push([
      audit_severity_name(finding.severity),
      audit_code_name(finding.code),
      finding.count.to_string(),
      finding.message,
    ])
  }
  csv_render(
    csv_table(["severity", "code", "count", "message"], rows),
    csv_default_options(),
  )
}

///|
pub fn audit_country_coverage(report : TradeImportReport) -> Int {
  audit_distinct_countries(report.records).length()
}

///|
pub fn audit_year_coverage(report : TradeImportReport) -> Int {
  audit_distinct_years(report.records).length()
}

///|
pub fn audit_duplicate_count(report : TradeImportReport) -> Int {
  audit_duplicate_records(report.records)
}

///|
pub fn audit_rule_weight(rule : ConcordanceRule) -> Double {
  audit_rule_weight_total(rule)
}
