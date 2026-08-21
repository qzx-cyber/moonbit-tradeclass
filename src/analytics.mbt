///|
pub struct NumericSummary {
  count : Int
  missing : Int
  total : Double
  minimum : Double?
  maximum : Double?
  mean : Double
  variance : Double
} derive(Debug, Eq)

///|
pub struct WeightedObservation {
  key : String
  value : Double
  weight : Double
} derive(Debug, Eq)

///|
pub fn weighted_observation(
  key : String,
  value : Double,
  weight : Double,
) -> WeightedObservation {
  { key, value, weight }
}

///|
pub struct QuantileBand {
  lower : Double
  median : Double
  upper : Double
} derive(Debug, Eq)

///|
pub fn empty_numeric_summary() -> NumericSummary {
  {
    count: 0,
    missing: 0,
    total: 0.0,
    minimum: None,
    maximum: None,
    mean: 0.0,
    variance: 0.0,
  }
}

///|
pub fn summarize(values : Array[Double]) -> NumericSummary {
  if values.is_empty() {
    return empty_numeric_summary()
  }
  let mut total = 0.0
  let mut minimum : Double? = None
  let mut maximum : Double? = None
  for value in values {
    total += value
    match minimum {
      None => minimum = Some(value)
      Some(current) => if value < current { minimum = Some(value) }
    }
    match maximum {
      None => maximum = Some(value)
      Some(current) => if value > current { maximum = Some(value) }
    }
  }
  let count = values.length()
  let mean = total / count.to_double()
  let mut squared = 0.0
  for value in values {
    let delta = value - mean
    squared += delta * delta
  }
  {
    count,
    missing: 0,
    total,
    minimum,
    maximum,
    mean,
    variance: squared / count.to_double(),
  }
}

///|
pub fn summarize_optional(values : Array[Double?]) -> NumericSummary {
  let present : Array[Double] = []
  let mut missing = 0
  for value in values {
    match value {
      Some(number) => present.push(number)
      None => missing += 1
    }
  }
  let summary = summarize(present)
  { ..summary, missing, }
}

///|
pub fn sum(values : Array[Double]) -> Double {
  let mut result = 0.0
  for value in values {
    result += value
  }
  result
}

///|
pub fn mean(values : Array[Double]) -> Double {
  if values.is_empty() {
    0.0
  } else {
    sum(values) / values.length().to_double()
  }
}

///|
pub fn weighted_sum(values : Array[WeightedObservation]) -> Double {
  let mut result = 0.0
  for observation in values {
    result += observation.value * observation.weight
  }
  result
}

///|
pub fn weight_total(values : Array[WeightedObservation]) -> Double {
  let mut result = 0.0
  for observation in values {
    result += observation.weight
  }
  result
}

///|
pub fn weighted_mean(values : Array[WeightedObservation]) -> Double {
  let total = weight_total(values)
  if total == 0.0 {
    0.0
  } else {
    weighted_sum(values) / total
  }
}

///|
pub fn sorted_numbers(values : Array[Double]) -> Array[Double] {
  let result = values.copy()
  let mut i = 0
  while i < result.length() {
    let mut j = i + 1
    while j < result.length() {
      if result[j] < result[i] {
        let temporary = result[i]
        result[i] = result[j]
        result[j] = temporary
      }
      j += 1
    }
    i += 1
  }
  result
}

///|
pub fn quantile(values : Array[Double], fraction : Double) -> Double? {
  if values.is_empty() || fraction < 0.0 || fraction > 1.0 {
    return None
  }
  let sorted = sorted_numbers(values)
  let position = fraction * (sorted.length() - 1).to_double()
  let lower = position.to_int()
  let upper = if lower + 1 < sorted.length() { lower + 1 } else { lower }
  let remainder = position - lower.to_double()
  Some(sorted[lower] + (sorted[upper] - sorted[lower]) * remainder)
}

///|
pub fn quantile_band(values : Array[Double]) -> QuantileBand? {
  match
    (quantile(values, 0.25), quantile(values, 0.5), quantile(values, 0.75)) {
    (Some(lower), Some(median), Some(upper)) => Some({ lower, median, upper })
    _ => None
  }
}

///|
pub fn frequency(keys : Array[String]) -> Array[(String, Int)] {
  let result : Array[(String, Int)] = []
  for key in keys {
    let mut found = false
    let mut index = 0
    while index < result.length() {
      if result[index].0 == key {
        result[index] = (key, result[index].1 + 1)
        found = true
        break
      }
      index += 1
    }
    if !found {
      result.push((key, 1))
    }
  }
  result
}

///|
pub fn group_sum(values : Array[(String, Double)]) -> Array[(String, Double)] {
  let result : Array[(String, Double)] = []
  for pair in values {
    let mut found = false
    let mut index = 0
    while index < result.length() {
      if result[index].0 == pair.0 {
        result[index] = (pair.0, result[index].1 + pair.1)
        found = true
        break
      }
      index += 1
    }
    if !found {
      result.push(pair)
    }
  }
  result
}

///|
pub fn normalize_weights(weights : Array[Double]) -> Array[Double] {
  let total = sum(weights)
  if total <= 0.0 {
    return weights.map(fn(_) { 0.0 })
  }
  weights.map(fn(value) { value / total })
}

///|
pub fn entropy(weights : Array[Double]) -> Double {
  let normalized = normalize_weights(weights)
  let mut result = 0.0
  for weight in normalized {
    if weight > 0.0 {
      result += weight * (1.0 - weight)
    }
  }
  result
}

///|
pub fn herfindahl_index(weights : Array[Double]) -> Double {
  let normalized = normalize_weights(weights)
  let mut result = 0.0
  for weight in normalized {
    result += weight * weight
  }
  result
}

///|
pub fn concentration_label(weights : Array[Double]) -> String {
  let index = herfindahl_index(weights)
  if index >= 0.25 {
    "high"
  } else if index >= 0.15 {
    "medium"
  } else {
    "low"
  }
}

///|
pub fn absolute_change(previous : Double, current : Double) -> Double {
  if current >= previous {
    current - previous
  } else {
    previous - current
  }
}

///|
pub fn relative_change(previous : Double, current : Double) -> Double? {
  if previous == 0.0 {
    None
  } else {
    Some((current - previous) / previous)
  }
}

///|
pub fn moving_sum(values : Array[Double], window : Int) -> Array[Double] {
  let result : Array[Double] = []
  if window <= 0 {
    return result
  }
  let mut start = 0
  while start + window <= values.length() {
    let mut total = 0.0
    let mut index = start
    while index < start + window {
      total += values[index]
      index += 1
    }
    result.push(total)
    start += 1
  }
  result
}

///|
pub fn moving_mean(values : Array[Double], window : Int) -> Array[Double] {
  moving_sum(values, window).map(fn(value) { value / window.to_double() })
}

///|
pub fn difference(values : Array[Double]) -> Array[Double] {
  let result : Array[Double] = []
  if values.length() < 2 {
    return result
  }
  let mut index = 1
  while index < values.length() {
    result.push(values[index] - values[index - 1])
    index += 1
  }
  result
}

///|
pub fn cumulative_sum(values : Array[Double]) -> Array[Double] {
  let result : Array[Double] = []
  let mut total = 0.0
  for value in values {
    total += value
    result.push(total)
  }
  result
}

///|
pub fn bounded(value : Double, lower : Double, upper : Double) -> Double {
  if value < lower {
    lower
  } else if value > upper {
    upper
  } else {
    value
  }
}

///|
pub fn proportion(part : Double, whole : Double) -> Double? {
  if whole == 0.0 {
    None
  } else {
    Some(part / whole)
  }
}

///|
pub fn share_table(values : Array[(String, Double)]) -> Array[(String, Double)] {
  let grouped = group_sum(values)
  let mut total = 0.0
  for pair in grouped {
    total += pair.1
  }
  if total == 0.0 {
    grouped.map(fn(pair) { (pair.0, 0.0) })
  } else {
    grouped.map(fn(pair) { (pair.0, pair.1 / total) })
  }
}
