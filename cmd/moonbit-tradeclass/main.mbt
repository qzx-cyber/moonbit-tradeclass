///|
fn main {
  let target = @tradeclass.mapping_target("SITC001", 1.0) catch {
    err => abort(err.to_string())
  }
  let rule = @tradeclass.concordance_rule(
    "0101",
    [target],
    @tradeclass.exact_confidence(),
    "built-in demonstration",
  ) catch {
    err => abort(err.to_string())
  }
  let result = @tradeclass.map_code(@tradeclass.concordance([rule]), "0101")
  println("moonbit-tradeclass map demo")
  println("0101 -> " + result.targets[0].code)
  println(
    "benchmark records: " + @tradeclass.benchmark_record_count().to_string(),
  )
  println("benchmark rules: " + @tradeclass.benchmark_rule_count().to_string())
  println(
    "benchmark scenarios: " + @tradeclass.benchmark_scenario_count().to_string(),
  )
  println(
    "benchmark profiles: " + @tradeclass.benchmark_profile_count().to_string(),
  )
  println(
    "benchmark metrics: " + @tradeclass.benchmark_metric_count().to_string(),
  )
  println(
    "benchmark thresholds: " +
    @tradeclass.benchmark_threshold_count().to_string(),
  )
  println(
    "benchmark work units: " + @tradeclass.benchmark_work_units().to_string(),
  )
  println("Use the library API to connect licensed CSV/JSON datasets.")
}
