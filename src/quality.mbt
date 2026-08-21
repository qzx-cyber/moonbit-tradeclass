///|
pub enum QualitySeverity {
  Info
  Warning
  Error
} derive(Debug, Eq)

///|
pub enum QualityCode {
  EmptySource
  EmptyTarget
  InvalidWeight
  WeightNotNormalized
  DuplicateRule
  DuplicateTarget
  MissingReason
  RetiredProduct
  MissingParent
  Cycle
} derive(Debug, Eq)

///|
pub struct QualityFinding {
  severity : QualitySeverity
  code : QualityCode
  subject : String
  message : String
} derive(Debug, Eq)

///|
pub struct QualitySummary {
  inspected_rules : Int
  inspected_targets : Int
  findings : Array[QualityFinding]
} derive(Debug)

///|
pub fn quality_finding(
  severity : QualitySeverity,
  code : QualityCode,
  subject : String,
  message : String,
) -> QualityFinding {
  { severity, code, subject, message }
}

///|
pub fn quality_summary(rules : Array[ConcordanceRule]) -> QualitySummary {
  let findings : Array[QualityFinding] = []
  let mut target_count = 0
  let mut rule_index = 0
  for rule in rules {
    if rule.from.trim() == "" {
      findings.push(
        quality_finding(Error, EmptySource, rule.from, "rule source is empty"),
      )
    }
    if rule.reason.trim() == "" {
      findings.push(
        quality_finding(
          Warning,
          MissingReason,
          rule.from,
          "rule reason is empty",
        ),
      )
    }
    if rule.to.is_empty() && rule.confidence != Unmappable {
      findings.push(
        quality_finding(
          Error,
          EmptyTarget,
          rule.from,
          "usable rule has no target",
        ),
      )
    }
    let mut total = 0.0
    let mut target_index = 0
    for target in rule.to {
      target_count += 1
      total += target.weight
      if target.code.trim() == "" {
        findings.push(
          quality_finding(Error, EmptyTarget, rule.from, "target code is empty"),
        )
      }
      if target.weight < 0.0 {
        findings.push(
          quality_finding(
            Error,
            InvalidWeight,
            target.code,
            "target weight is negative",
          ),
        )
      }
      let mut duplicate = false
      let mut prior = 0
      while prior < target_index {
        if rule.to[prior].code == target.code {
          duplicate = true
        }
        prior += 1
      }
      if duplicate {
        findings.push(
          quality_finding(
            Warning,
            DuplicateTarget,
            target.code,
            "target appears more than once",
          ),
        )
      }
      target_index += 1
    }
    if rule.confidence != Unmappable &&
      total > 0.0 &&
      absolute_change(total, 1.0) > 0.000001 {
      findings.push(
        quality_finding(
          Warning,
          WeightNotNormalized,
          rule.from,
          "target weights do not sum to one",
        ),
      )
    }
    let mut prior_rule = 0
    while prior_rule < rule_index {
      if rules[prior_rule].from == rule.from {
        findings.push(
          quality_finding(
            Error,
            DuplicateRule,
            rule.from,
            "source has duplicate rules",
          ),
        )
      }
      prior_rule += 1
    }
    rule_index += 1
  }
  { inspected_rules: rules.length(), inspected_targets: target_count, findings }
}

///|
pub fn quality_has_errors(summary : QualitySummary) -> Bool {
  for finding in summary.findings {
    if finding.severity == Error {
      return true
    }
  }
  false
}

///|
pub fn quality_error_count(summary : QualitySummary) -> Int {
  let mut count = 0
  for finding in summary.findings {
    if finding.severity == Error {
      count += 1
    }
  }
  count
}

///|
pub fn quality_warning_count(summary : QualitySummary) -> Int {
  let mut count = 0
  for finding in summary.findings {
    if finding.severity == Warning {
      count += 1
    }
  }
  count
}

///|
pub fn quality_findings_for(
  summary : QualitySummary,
  subject : String,
) -> Array[QualityFinding] {
  let result : Array[QualityFinding] = []
  for finding in summary.findings {
    if finding.subject == subject {
      result.push(finding)
    }
  }
  result
}

///|
pub fn quality_code_name(code : QualityCode) -> String {
  match code {
    EmptySource => "empty_source"
    EmptyTarget => "empty_target"
    InvalidWeight => "invalid_weight"
    WeightNotNormalized => "weight_not_normalized"
    DuplicateRule => "duplicate_rule"
    DuplicateTarget => "duplicate_target"
    MissingReason => "missing_reason"
    RetiredProduct => "retired_product"
    MissingParent => "missing_parent"
    Cycle => "cycle"
  }
}

///|
pub fn quality_severity_name(severity : QualitySeverity) -> String {
  match severity {
    Info => "info"
    Warning => "warning"
    Error => "error"
  }
}

///|
pub fn quality_report_lines(summary : QualitySummary) -> Array[String] {
  let lines : Array[String] = []
  lines.push("rules=" + summary.inspected_rules.to_string())
  lines.push("targets=" + summary.inspected_targets.to_string())
  lines.push("findings=" + summary.findings.length().to_string())
  for finding in summary.findings {
    lines.push(
      quality_severity_name(finding.severity) +
      " " +
      quality_code_name(finding.code) +
      " " +
      finding.subject +
      " " +
      finding.message,
    )
  }
  lines
}

///|
pub fn quality_report(summary : QualitySummary) -> String {
  let builder = StringBuilder::new()
  for line in quality_report_lines(summary) {
    builder.write_string(line)
    builder.write_char('\n')
  }
  builder.to_string()
}

///|
pub fn catalog_quality(
  catalog : ClassificationCatalog,
) -> Array[QualityFinding] {
  let findings : Array[QualityFinding] = []
  for product in catalog.products {
    match product.parent {
      Some(parent) =>
        if catalog_find_product(
            catalog,
            product.version.system.id,
            product.version.label,
            parent,
          )
          is None {
          findings.push(
            quality_finding(
              Warning,
              MissingParent,
              product.code,
              "parent code is not in catalog",
            ),
          )
        }
      None => ()
    }
    if product.state == Retired {
      findings.push(
        quality_finding(
          Info,
          RetiredProduct,
          product.code,
          "product is retired",
        ),
      )
    }
  }
  findings
}

///|
pub fn combined_quality(
  catalog : ClassificationCatalog,
  book : Concordance,
) -> Array[QualityFinding] {
  let result = catalog_quality(catalog)
  let summary = quality_summary(book.rules)
  for finding in summary.findings {
    result.push(finding)
  }
  result
}

///|
pub fn quality_score(summary : QualitySummary) -> Double {
  if summary.inspected_rules == 0 {
    return 1.0
  }
  let errors = quality_error_count(summary).to_double()
  let warnings = quality_warning_count(summary).to_double()
  let score = 1.0 -
    (errors * 1.0 + warnings * 0.25) / summary.inspected_rules.to_double()
  bounded(score, 0.0, 1.0)
}
