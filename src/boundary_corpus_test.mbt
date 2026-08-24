///|
test "normalization boundary corpus" {
  for index in 0..<200 {
    let code = "HS" + (index + 1).to_string()
    let formatted = if index % 3 == 0 {
      " " + code + " "
    } else if index % 3 == 1 {
      " " + code + "-"
    } else {
      code.to_lower()
    }
    let report = normalize_code(formatted, default_normalization_policy())
    assert_eq(report.normalized, code.to_upper())
    assert_eq(code_depth(report.normalized), code.length())
    assert_eq(code_prefix(report.normalized, 2), "HS")
    assert_true(
      code_is_prefix(code_prefix(report.normalized, 2), report.normalized),
    )
  }
}

///|
test "benchmark dataset invariants" {
  assert_eq(benchmark_record_count(), 1000)
  assert_eq(benchmark_scenario_count(), 2000)
  assert_eq(benchmark_rule_count(), 1600)
  assert_eq(benchmark_metric_count(), 1100)
  assert_eq(benchmark_profile_count(), 500)
  assert_eq(benchmark_threshold_count(), 700)
  assert_true(benchmark_total_amount() > 0.0)
  assert_true(benchmark_work_units() > benchmark_scenario_count())
  assert_true(benchmark_max_depth() == 12)
  assert_true(benchmark_max_input_size() == 109)
  assert_true(benchmark_code_checksum() > 0)
  assert_eq(benchmark_metric_categories().length(), 5)
}
