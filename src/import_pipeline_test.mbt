///|
test "csv parser handles quoted delimiters and escaped quotes" {
  let text = "code,country,note\n0101,CN,plain\n\"0102\",US,\"contains, comma\"\n0103,DE,\"says \"\"hello\"\"\"\n"
  let result = csv_parse(text, csv_default_options())
  match result {
    CsvInvalid(issues) =>
      fail("unexpected CSV errors: " + issues.length().to_string())
    CsvOk(table) => {
      assert_eq(csv_table_row_count(table), 3)
      assert_eq(csv_table_column_count(table), 3)
      assert_eq(csv_cell(table, 1, 2), Some("contains, comma"))
      assert_eq(csv_cell(table, 2, 2), Some("says \"hello\""))
    }
  }
}

///|
test "csv parser accepts CRLF and skips blank rows" {
  let text = "code;country;amount\r\n0101;CN;12.5\r\n\r\n0102;US;7.5\r\n"
  let options = csv_options(';', '"', true, true)
  match csv_parse(text, options) {
    CsvInvalid(_) => fail("CRLF input should parse")
    CsvOk(table) => {
      assert_eq(csv_table_row_count(table), 2)
      assert_eq(csv_cell(table, 0, 0), Some("0101"))
      assert_eq(csv_cell(table, 1, 1), Some("US"))
    }
  }
}

///|
test "csv parser reports malformed quotes and widths" {
  let unterminated = csv_parse(
    "code,country\n\"0101,CN\n",
    csv_default_options(),
  )
  assert_true(!csv_is_valid(unterminated))
  assert_eq(csv_issue_count(unterminated), 1)
  let inconsistent = csv_parse(
    "code,country\n0101,CN,extra\n",
    csv_default_options(),
  )
  assert_true(!csv_is_valid(inconsistent))
  assert_eq(csv_issue_count(inconsistent), 1)
}

///|
test "csv table projection and escaping are deterministic" {
  let table = csv_table(["code", "note", "amount"], [
    ["0101", "contains, comma", "12.5"],
    ["0102", "plain", "7.5"],
  ])
  assert_eq(csv_header_index(table, "NOTE"), Some(1))
  assert_eq(csv_column(table, "code"), ["0101", "0102"])
  let selected = csv_select_columns(table, ["amount", "code"])
  match selected {
    CsvInvalid(_) => fail("projection should find both columns")
    CsvOk(projected) => {
      assert_eq(csv_headers(projected), ["amount", "code"])
      assert_eq(csv_cell(projected, 0, 0), Some("12.5"))
    }
  }
  let rendered = csv_render(table, csv_default_options())
  assert_true(rendered.contains("\"contains, comma\""))
  match csv_parse(rendered, csv_default_options()) {
    CsvInvalid(_) => fail("rendered table should round-trip")
    CsvOk(round_trip) => assert_eq(csv_rows(round_trip), csv_rows(table))
  }
}

///|
test "trade import accepts valid rows and aggregates totals" {
  let text = "code,country,year,amount\n0101,CN,2022,100.5\n0102,CN,2022,20.5\n0103,US,2023,50\n"
  let report = import_trade_csv(text, default_trade_import_options())
  assert_eq(import_input_row_count(report), 3)
  assert_eq(import_accepted_count(report), 3)
  assert_eq(import_rejected_count(report), 0)
  assert_true(import_is_successful(report))
  assert_eq(import_total_amount(report), 171.0)
  assert_eq(import_country_totals(report), [("CN", 121.0), ("US", 50.0)])
  assert_eq(import_year_totals(report), [(2022, 121.0), (2023, 50.0)])
  assert_eq(import_min_amount(report), Some(20.5))
  assert_eq(import_max_amount(report), Some(100.5))
  assert_eq(import_mean_amount(report), Some(57.0))
}

///|
test "trade import reports every invalid row" {
  let text = "code,country,year,amount\n" +
    "0101,CN,2022,10\n" +
    "0101,CN,2022,11\n" +
    "0102,C,2022,-3\n" +
    "0103,US,not-year,4\n" +
    "0104,DE,2022,NaN\n"
  let report = import_trade_csv(text, default_trade_import_options())
  assert_eq(import_accepted_count(report), 1)
  assert_eq(import_rejected_count(report), 4)
  assert_eq(import_issue_count(report), 5)
  assert_true(!import_is_successful(report))
  assert_true(import_acceptance_ratio(report) > 0.19)
  assert_true(import_acceptance_ratio(report) < 0.3)
  assert_true(!import_quality_gate(report, 3, 0.5))
  let lines = import_issue_lines(report)
  assert_true(lines[0].contains("duplicate"))
  assert_true(import_report_markdown(report).contains("Rejected rows: 4"))
}

///|
test "trade import can be configured for signed values and duplicates" {
  let text = "code,country,year,amount\n0101,CN,2022,-5\n0101,CN,2022,5\n"
  let allow_signed = trade_import_options(
    "code", "country", "year", "amount", true, 2000, 2030, false,
  )
  let report = import_trade_csv(text, allow_signed)
  assert_eq(import_accepted_count(report), 2)
  assert_eq(import_rejected_count(report), 0)
  assert_eq(import_total_amount(report), 0.0)
  assert_true(import_quality_gate(report, 0, 1.0))
}

///|
test "trade import validates required headers" {
  let text = "code,country,amount\n0101,CN,10\n"
  let report = import_trade_csv(text, default_trade_import_options())
  assert_eq(import_accepted_count(report), 0)
  assert_eq(import_rejected_count(report), 1)
  assert_true(import_issue_count(report) > 0)
  assert_true(import_issue_lines(report)[0].contains("year"))
}

///|
test "query filters records by dimensions and amount" {
  let text = "code,country,year,amount\n" +
    "0101,CN,2022,100\n" +
    "0102,CN,2023,200\n" +
    "0103,US,2022,300\n" +
    "0201,CN,2022,400\n"
  let report = import_trade_csv(text, default_trade_import_options())
  let query = trade_query(
    Some("CN"),
    Some(2022),
    Some("01"),
    Some(50.0),
    Some(150.0),
    0,
  )
  let selected = query_report(report, query)
  assert_eq(selected.length(), 1)
  assert_eq(selected[0].code, "0101")
  assert_eq(query_total_amount(selected), 100.0)
  let empty = query_records(
    import_records(report),
    trade_query(Some("JP"), None, None, None, None, 0),
  )
  assert_true(empty.is_empty())
}

///|
test "query ordering and pagination are stable" {
  let records = [
    trade_record("CN", 2022, "0103", 30.0),
    trade_record("CN", 2022, "0101", 10.0),
    trade_record("US", 2022, "0102", 20.0),
  ]
  let descending = query_sorted_by_amount(records, true)
  assert_eq(descending[0].amount, 30.0)
  assert_eq(descending[2].amount, 10.0)
  let ascending = query_sorted_by_amount(records, false)
  assert_eq(ascending[0].amount, 10.0)
  let by_code = query_sorted_by_code(records)
  assert_eq(by_code[0].code, "0101")
  let page = query_page(by_code, 1, 2)
  assert_eq(page.length(), 2)
  assert_eq(page[0].code, "0102")
  assert_eq(query_page(records, -1, 2), [])
  assert_eq(query_page(records, 1, 0), [])
}

///|
test "query counts and CSV export preserve records" {
  let records = [
    trade_record("CN", 2022, "0101", 1.0),
    trade_record("CN", 2023, "0102", 2.0),
    trade_record("US", 2022, "0103", 3.0),
  ]
  assert_eq(query_country_counts(records), [("CN", 2), ("US", 1)])
  assert_eq(query_year_counts(records), [(2022, 2), (2023, 1)])
  let table = records_to_csv(records)
  assert_eq(csv_table_row_count(table), 3)
  let text = csv_render(table, csv_default_options())
  let report = import_trade_csv(text, default_trade_import_options())
  assert_eq(import_accepted_count(report), 3)
  assert_eq(import_total_amount(report), 6.0)
}

///|
test "parameterized import remains deterministic across a larger batch" {
  let builder = StringBuilder()
  builder.write_string("code,country,year,amount\n")
  for index in 0..<120 {
    builder.write_string(
      "HS" +
      index.to_string() +
      "," +
      (if index % 2 == 0 { "CN" } else { "US" }) +
      "," +
      (2020 + index % 3).to_string() +
      "," +
      (index * 10 + 1).to_string() +
      "\n",
    )
  }
  let text = builder.to_string()
  let first = import_trade_csv(text, default_trade_import_options())
  let second = import_trade_csv(text, default_trade_import_options())
  assert_eq(import_accepted_count(first), 120)
  assert_eq(import_accepted_count(first), import_accepted_count(second))
  assert_eq(import_total_amount(first), import_total_amount(second))
  assert_eq(import_country_totals(first), import_country_totals(second))
  assert_true(import_quality_gate(first, 0, 1.0))
}

///|
test "empty and malformed input produce safe reports" {
  let empty = import_trade_csv("", default_trade_import_options())
  assert_eq(import_accepted_count(empty), 0)
  assert_eq(import_rejected_count(empty), 0)
  assert_true(import_issue_count(empty) > 0)
  let malformed = import_trade_csv(
    "code,country,year,amount\n\"0101,CN,2022,1\n",
    default_trade_import_options(),
  )
  assert_eq(import_accepted_count(malformed), 0)
  assert_true(import_issue_count(malformed) > 0)
  assert_eq(import_min_amount(empty), None)
  assert_eq(import_max_amount(empty), None)
  assert_eq(import_mean_amount(empty), None)
}
