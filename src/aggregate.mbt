///|
pub struct AggregationPlan {
  level : Int
  include_country : Bool
  include_year : Bool
} derive(Debug, Eq)

///|
pub struct TradeRecord {
  country : String
  year : Int
  code : String
  amount : Double
} derive(Debug, Eq)

///|
pub struct AggregatedRecord {
  country : String
  year : Int
  code : String
  mut amount : Double
} derive(Debug, Eq)

///|
pub fn aggregation_plan(
  level : Int,
  include_country : Bool,
  include_year : Bool,
) -> AggregationPlan {
  { level, include_country, include_year }
}

///|
pub fn trade_record(
  country : String,
  year : Int,
  code : String,
  amount : Double,
) -> TradeRecord {
  { country, year, code, amount }
}

///|
pub fn aggregate(
  plan : AggregationPlan,
  records : Array[TradeRecord],
) -> Array[AggregatedRecord] {
  let output : Array[AggregatedRecord] = []
  for record in records {
    let key_code = if plan.level <= 0 { "" } else { record.code }
    let key_country = if plan.include_country { record.country } else { "" }
    let key_year = if plan.include_year { record.year } else { 0 }
    let mut found = false
    for item in output {
      if item.code == key_code &&
        item.country == key_country &&
        item.year == key_year {
        item.amount += record.amount
        found = true
      }
    }
    if !found {
      output.push({
        country: key_country,
        year: key_year,
        code: key_code,
        amount: record.amount,
      })
    }
  }
  output
}
