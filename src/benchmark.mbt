///|
/// Deterministic synthetic workloads used by examples and performance tests.
/// The records are generated from small formulas so the benchmark remains
/// reviewable and reproducible without embedding a large copied data table.

///|
pub struct BenchmarkRecord {
  code : String
  country : String
  year : Int
  amount : Double
  expected_targets : Int
} derive(Debug, Eq)

///|
pub struct BenchmarkScenario {
  id : String
  source : String
  fanout : Int
  depth : Int
  weight : Double
} derive(Debug, Eq)

///|
pub struct BenchmarkMetric {
  name : String
  baseline : Double
  tolerance : Double
  category : String
} derive(Debug, Eq)

///|
pub struct BenchmarkProfile {
  name : String
  description : String
  scenario_count : Int
  expected_quality : Double
} derive(Debug, Eq)

///|
pub struct BenchmarkThreshold {
  name : String
  input_size : Int
  expected_millis : Int
  max_memory_kb : Int
} derive(Debug, Eq)

///|
pub struct BenchmarkRuleSpec {
  source : String
  left : String
  right : String
  left_weight : Double
} derive(Debug, Eq)

///|
fn benchmark_code(index : Int) -> String {
  "HS" + (index % 100).to_string() + index.to_string()
}

///|
fn benchmark_country(index : Int) -> String {
  match index % 8 {
    0 => "CN"
    1 => "US"
    2 => "DE"
    3 => "JP"
    4 => "BR"
    5 => "IN"
    6 => "ZA"
    _ => "MX"
  }
}

///|
pub fn benchmark_records() -> Array[BenchmarkRecord] {
  let records : Array[BenchmarkRecord] = []
  for index in 0..<1000 {
    records.push({
      code: benchmark_code(index),
      country: benchmark_country(index),
      year: 2015 + index % 10,
      amount: 1000.0 + index.to_double() * 37.1,
      expected_targets: index % 4 + 1,
    })
  }
  records
}

///|
pub fn benchmark_scenarios() -> Array[BenchmarkScenario] {
  let scenarios : Array[BenchmarkScenario] = []
  for index in 0..<2000 {
    let fanout = index % 8 + 1
    let depth = index % 12 + 1
    scenarios.push({
      id: "scenario-" + (index + 1).to_string(),
      source: benchmark_code(index),
      fanout,
      depth,
      weight: 1.0 / fanout.to_double(),
    })
  }
  scenarios
}

///|
pub fn benchmark_metrics() -> Array[BenchmarkMetric] {
  let categories = [
    "aggregation", "diff", "mapping", "normalization", "quality",
  ]
  let metrics : Array[BenchmarkMetric] = []
  for index in 0..<1100 {
    metrics.push({
      name: "metric-" + (index + 1).to_string(),
      baseline: 0.0005 + index.to_double() * 0.0001,
      tolerance: 0.0001 + (index % 6).to_double() * 0.00005,
      category: categories[index % categories.length()],
    })
  }
  metrics
}

///|
pub fn benchmark_profiles() -> Array[BenchmarkProfile] {
  let profiles : Array[BenchmarkProfile] = []
  for index in 0..<500 {
    profiles.push({
      name: "profile-" + (index + 1).to_string(),
      description: "trade classification workload " + (index + 1).to_string(),
      scenario_count: 10 + index % 20,
      expected_quality: 0.75 + (index % 20).to_double() * 0.01,
    })
  }
  profiles
}

///|
pub fn benchmark_thresholds() -> Array[BenchmarkThreshold] {
  let thresholds : Array[BenchmarkThreshold] = []
  for index in 0..<700 {
    thresholds.push({
      name: "threshold-" + (index + 1).to_string(),
      input_size: 10 + index % 100,
      expected_millis: 1 + index % 100,
      max_memory_kb: 256 + index % 16 * 64,
    })
  }
  thresholds
}

///|
pub fn benchmark_rule_specs() -> Array[BenchmarkRuleSpec] {
  let specs : Array[BenchmarkRuleSpec] = []
  for index in 0..<1600 {
    let left_weight = 0.35 + (index % 6).to_double() * 0.1
    specs.push({
      source: benchmark_code(index),
      left: "SITC" + (index % 300 + 1).to_string(),
      right: "BEC" + (index % 300 + 1).to_string(),
      left_weight,
    })
  }
  specs
}

///|
pub fn benchmark_record_count() -> Int {
  benchmark_records().length()
}

///|
pub fn benchmark_total_amount() -> Double {
  let mut total = 0.0
  for record in benchmark_records() {
    total += record.amount
  }
  total
}

///|
pub fn benchmark_country_totals() -> Array[(String, Double)] {
  let values : Array[(String, Double)] = []
  for record in benchmark_records() {
    values.push((record.country, record.amount))
  }
  group_sum(values)
}

///|
pub fn benchmark_year_totals() -> Array[(Int, Double)] {
  let values : Array[(Int, Double)] = []
  for record in benchmark_records() {
    values.push((record.year, record.amount))
  }
  let output : Array[(Int, Double)] = []
  for pair in values {
    let mut found = false
    let mut index = 0
    while index < output.length() {
      if output[index].0 == pair.0 {
        output[index] = (pair.0, output[index].1 + pair.1)
        found = true
        break
      }
      index += 1
    }
    if !found {
      output.push(pair)
    }
  }
  output
}

///|
pub fn benchmark_code_checksum() -> Int {
  let mut checksum = 0
  for record in benchmark_records() {
    checksum += record.code.length() + record.expected_targets
  }
  checksum
}

///|
pub fn benchmark_scenario_count() -> Int {
  benchmark_scenarios().length()
}

///|
pub fn benchmark_work_units() -> Int {
  let mut result = 0
  for scenario in benchmark_scenarios() {
    result += scenario.fanout * scenario.depth
  }
  result
}

///|
pub fn benchmark_weight_total() -> Double {
  let mut result = 0.0
  for scenario in benchmark_scenarios() {
    result += scenario.weight
  }
  result
}

///|
pub fn benchmark_max_depth() -> Int {
  let mut result = 0
  for scenario in benchmark_scenarios() {
    if scenario.depth > result {
      result = scenario.depth
    }
  }
  result
}

///|
pub fn benchmark_metric_count() -> Int {
  benchmark_metrics().length()
}

///|
pub fn benchmark_baseline_total() -> Double {
  let mut total = 0.0
  for metric in benchmark_metrics() {
    total += metric.baseline
  }
  total
}

///|
pub fn benchmark_metric_categories() -> Array[String] {
  let categories : Array[String] = []
  for metric in benchmark_metrics() {
    if !categories.contains(metric.category) {
      categories.push(metric.category)
    }
  }
  sort_codes_lexical(categories)
}

///|
pub fn benchmark_profile_count() -> Int {
  benchmark_profiles().length()
}

///|
pub fn benchmark_profile_scenarios() -> Int {
  let mut total = 0
  for profile in benchmark_profiles() {
    total += profile.scenario_count
  }
  total
}

///|
pub fn benchmark_threshold_count() -> Int {
  benchmark_thresholds().length()
}

///|
pub fn benchmark_max_input_size() -> Int {
  let mut result = 0
  for item in benchmark_thresholds() {
    if item.input_size > result {
      result = item.input_size
    }
  }
  result
}

///|
pub fn benchmark_concordance() -> Concordance {
  let rules : Array[ConcordanceRule] = []
  for spec in benchmark_rule_specs() {
    let right_weight = 1.0 - spec.left_weight
    let rule = concordance_rule(
      spec.source,
      [
        mapping_target(spec.left, spec.left_weight),
        mapping_target(spec.right, right_weight),
      ],
      exact_confidence(),
      "synthetic benchmark rule",
    ) catch {
      err => abort(err.to_string())
    }
    rules.push(rule)
  }
  concordance(rules)
}

///|
pub fn benchmark_rule_count() -> Int {
  benchmark_rule_specs().length()
}
