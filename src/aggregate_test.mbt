///|
test "aggregates trade records by country and year" {
  let plan = aggregation_plan(2, true, true)
  let records = aggregate(plan, [
    trade_record("CN", 2024, "0101", 10.0),
    trade_record("CN", 2024, "0101", 2.5),
    trade_record("US", 2024, "0101", 4.0),
  ])
  debug_inspect(records.length(), content="2")
  debug_inspect(
    records[0].amount,
    content=(
      #|12.5
    ),
  )
}

///|
test "aggregates all records when dimensions are disabled" {
  let records = aggregate(aggregation_plan(0, false, false), [
    trade_record("CN", 2024, "0101", 3.0),
    trade_record("US", 2025, "0201", 7.0),
  ])
  debug_inspect(records.length(), content="1")
  debug_inspect(
    records[0].amount,
    content=(
      #|10
    ),
  )
}
