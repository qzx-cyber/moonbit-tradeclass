///|
/// Production-facing import and query primitives built on top of the pure
/// domain model. The module intentionally returns reports instead of raising
/// on user data: a scheduled import should be able to explain every rejected
/// row and still process the valid portion of a batch.

///|
pub enum ImportIssueKind {
  MissingField
  InvalidCode
  InvalidCountry
  InvalidYear
  InvalidAmount
  NegativeAmount
  DuplicateRecord
  InvalidWeight
  InvalidConfidence
  InvalidRule
} derive(Debug, Eq)

///|
pub struct ImportIssue {
  row : Int
  field : String
  kind : ImportIssueKind
  message : String
} derive(Debug, Eq)

///|
pub fn import_issue(
  row : Int,
  field : String,
  kind : ImportIssueKind,
  message : String,
) -> ImportIssue {
  { row, field, kind, message }
}

///|
pub struct TradeImportOptions {
  code_column : String
  country_column : String
  year_column : String
  amount_column : String
  allow_negative_amount : Bool
  min_year : Int
  max_year : Int
  reject_duplicates : Bool
} derive(Debug, Eq)

///|
pub fn trade_import_options(
  code_column : String,
  country_column : String,
  year_column : String,
  amount_column : String,
  allow_negative_amount : Bool,
  min_year : Int,
  max_year : Int,
  reject_duplicates : Bool,
) -> TradeImportOptions {
  {
    code_column,
    country_column,
    year_column,
    amount_column,
    allow_negative_amount,
    min_year,
    max_year,
    reject_duplicates,
  }
}

///|
pub fn default_trade_import_options() -> TradeImportOptions {
  trade_import_options(
    "code", "country", "year", "amount", false, 1900, 2100, true,
  )
}

///|
pub struct TradeImportReport {
  records : Array[TradeRecord]
  issues : Array[ImportIssue]
  accepted : Int
  rejected : Int
  input_rows : Int
} derive(Debug, Eq)

///|
fn import_cell(row : Array[String], index : Int) -> String? {
  if index < 0 || index >= row.length() {
    None
  } else {
    Some(row[index].trim().to_owned())
  }
}

///|
fn import_column_index(table : CsvTable, name : String) -> Int {
  match csv_header_index(table, name) {
    None => -1
    Some(index) => index
  }
}

///|
fn import_parse_int(value : String) -> Int? {
  Some(@string.parse_int(value)) catch {
    _ => None
  }
}

///|
fn import_parse_double(value : String) -> Double? {
  Some(@string.parse_double(value)) catch {
    _ => None
  }
}

///|
fn import_is_nan(value : Double) -> Bool {
  value != value
}

///|
fn import_country_is_plausible(country : String) -> Bool {
  let normalized = country.trim().to_upper()
  let length = normalized.length()
  if length < 2 || length > 3 {
    return false
  }
  for ch in normalized {
    if (ch < 'A' || ch > 'Z') && ch != '*' {
      return false
    }
  }
  true
}

///|
fn import_issue_for_missing(row : Int, field : String) -> ImportIssue {
  import_issue(row, field, MissingField, "required field is empty")
}

///|
fn import_duplicate_key(record : TradeRecord) -> String {
  record.country + ":" + record.year.to_string() + ":" + record.code
}

///|
pub fn import_trade_table(
  table : CsvTable,
  options : TradeImportOptions,
) -> TradeImportReport {
  let issues : Array[ImportIssue] = []
  let records : Array[TradeRecord] = []
  let required = [
    options.code_column,
    options.country_column,
    options.year_column,
    options.amount_column,
  ]
  for issue in csv_require_columns(table, required) {
    issues.push(
      import_issue(issue.row, issue.message, MissingField, issue.message),
    )
  }
  if !issues.is_empty() {
    return {
      records,
      issues,
      accepted: 0,
      rejected: table.rows.length(),
      input_rows: table.rows.length(),
    }
  }
  let code_index = import_column_index(table, options.code_column)
  let country_index = import_column_index(table, options.country_column)
  let year_index = import_column_index(table, options.year_column)
  let amount_index = import_column_index(table, options.amount_column)
  let seen : Array[String] = []
  let mut rejected = 0
  let mut row_number = 2
  for row in table.rows {
    let row_issues : Array[ImportIssue] = []
    let code = match import_cell(row, code_index) {
      None => ""
      Some(value) => normalize_code_or_empty(value)
    }
    let country = match import_cell(row, country_index) {
      None => ""
      Some(value) => value.to_upper()
    }
    let year_value = match import_cell(row, year_index) {
      None => ""
      Some(value) => value
    }
    let amount_value = match import_cell(row, amount_index) {
      None => ""
      Some(value) => value
    }
    if code == "" {
      row_issues.push(import_issue_for_missing(row_number, options.code_column))
    }
    if !import_country_is_plausible(country) {
      row_issues.push(
        import_issue(
          row_number,
          options.country_column,
          InvalidCountry,
          "country must contain two or three ASCII letters",
        ),
      )
    }
    let parsed_year = match import_parse_int(year_value) {
      None => {
        row_issues.push(
          import_issue(
            row_number,
            options.year_column,
            InvalidYear,
            "year is not an integer",
          ),
        )
        0
      }
      Some(value) => {
        if value < options.min_year || value > options.max_year {
          row_issues.push(
            import_issue(
              row_number,
              options.year_column,
              InvalidYear,
              "year is outside the configured range",
            ),
          )
        }
        value
      }
    }
    let parsed_amount = match import_parse_double(amount_value) {
      None => {
        row_issues.push(
          import_issue(
            row_number,
            options.amount_column,
            InvalidAmount,
            "amount is not a number",
          ),
        )
        0.0
      }
      Some(value) => value
    }
    if import_is_nan(parsed_amount) {
      row_issues.push(
        import_issue(
          row_number,
          options.amount_column,
          InvalidAmount,
          "amount cannot be NaN",
        ),
      )
    }
    if !options.allow_negative_amount && parsed_amount < 0.0 {
      row_issues.push(
        import_issue(
          row_number,
          options.amount_column,
          NegativeAmount,
          "negative amounts are disabled by the import policy",
        ),
      )
    }
    let record = trade_record(country, parsed_year, code, parsed_amount)
    let duplicate = seen.contains(import_duplicate_key(record))
    if duplicate && options.reject_duplicates {
      row_issues.push(
        import_issue(
          row_number,
          options.code_column,
          DuplicateRecord,
          "country, year, and code already occurred in this batch",
        ),
      )
    }
    if row_issues.is_empty() {
      records.push(record)
      seen.push(import_duplicate_key(record))
    } else {
      rejected += 1
      for issue in row_issues {
        issues.push(issue)
      }
    }
    row_number += 1
  }
  {
    records,
    issues,
    accepted: records.length(),
    rejected,
    input_rows: table.rows.length(),
  }
}

///|
pub fn import_trade_csv(
  text : String,
  options : TradeImportOptions,
) -> TradeImportReport {
  match csv_parse(text, csv_default_options()) {
    CsvOk(table) => import_trade_table(table, options)
    CsvInvalid(csv_issues) => {
      let issues : Array[ImportIssue] = []
      for issue in csv_issues {
        issues.push(
          import_issue(
            issue.row,
            issue.column.to_string(),
            MissingField,
            issue.message,
          ),
        )
      }
      { records: [], issues, accepted: 0, rejected: 0, input_rows: 0 }
    }
  }
}

///|
pub fn import_records(report : TradeImportReport) -> Array[TradeRecord] {
  report.records.copy()
}

///|
pub fn import_issues(report : TradeImportReport) -> Array[ImportIssue] {
  report.issues.copy()
}

///|
pub fn import_accepted_count(report : TradeImportReport) -> Int {
  report.accepted
}

///|
pub fn import_rejected_count(report : TradeImportReport) -> Int {
  report.rejected
}

///|
pub fn import_input_row_count(report : TradeImportReport) -> Int {
  report.input_rows
}

///|
pub fn import_issue_count(report : TradeImportReport) -> Int {
  report.issues.length()
}

///|
pub fn import_is_successful(report : TradeImportReport) -> Bool {
  report.rejected == 0 && report.issues.is_empty()
}

///|
pub fn import_acceptance_ratio(report : TradeImportReport) -> Double {
  if report.input_rows <= 0 {
    0.0
  } else {
    report.accepted.to_double() / report.input_rows.to_double()
  }
}

///|
pub fn import_total_amount(report : TradeImportReport) -> Double {
  let mut total = 0.0
  for record in report.records {
    total += record.amount
  }
  total
}

///|
pub fn import_country_totals(
  report : TradeImportReport,
) -> Array[(String, Double)] {
  let values : Array[(String, Double)] = []
  for record in report.records {
    values.push((record.country, record.amount))
  }
  group_sum(values)
}

///|
pub fn import_year_totals(report : TradeImportReport) -> Array[(Int, Double)] {
  let output : Array[(Int, Double)] = []
  for record in report.records {
    let mut found = false
    let mut index = 0
    while index < output.length() {
      if output[index].0 == record.year {
        output[index] = (record.year, output[index].1 + record.amount)
        found = true
        break
      }
      index += 1
    }
    if !found {
      output.push((record.year, record.amount))
    }
  }
  output
}

///|
pub fn import_min_amount(report : TradeImportReport) -> Double? {
  if report.records.is_empty() {
    return None
  }
  let mut result = report.records[0].amount
  for record in report.records[1:] {
    if record.amount < result {
      result = record.amount
    }
  }
  Some(result)
}

///|
pub fn import_max_amount(report : TradeImportReport) -> Double? {
  if report.records.is_empty() {
    return None
  }
  let mut result = report.records[0].amount
  for record in report.records[1:] {
    if record.amount > result {
      result = record.amount
    }
  }
  Some(result)
}

///|
pub fn import_mean_amount(report : TradeImportReport) -> Double? {
  if report.records.is_empty() {
    None
  } else {
    Some(import_total_amount(report) / report.records.length().to_double())
  }
}

///|
pub fn import_quality_gate(
  report : TradeImportReport,
  maximum_rejected : Int,
  minimum_acceptance_ratio : Double,
) -> Bool {
  report.rejected <= maximum_rejected &&
  import_acceptance_ratio(report) >= minimum_acceptance_ratio
}

///|
fn import_issue_kind_name(kind : ImportIssueKind) -> String {
  match kind {
    MissingField => "missing_field"
    InvalidCode => "invalid_code"
    InvalidCountry => "invalid_country"
    InvalidYear => "invalid_year"
    InvalidAmount => "invalid_amount"
    NegativeAmount => "negative_amount"
    DuplicateRecord => "duplicate_record"
    InvalidWeight => "invalid_weight"
    InvalidConfidence => "invalid_confidence"
    InvalidRule => "invalid_rule"
  }
}

///|
pub fn import_issue_lines(report : TradeImportReport) -> Array[String] {
  let lines : Array[String] = []
  for issue in report.issues {
    lines.push(
      "row " +
      issue.row.to_string() +
      ": " +
      issue.field +
      " [" +
      import_issue_kind_name(issue.kind) +
      "] " +
      issue.message,
    )
  }
  lines
}

///|
pub fn import_report_markdown(report : TradeImportReport) -> String {
  let builder = StringBuilder()
  builder.write_string("## Import report\n\n")
  builder.write_string("- Input rows: " + report.input_rows.to_string() + "\n")
  builder.write_string("- Accepted rows: " + report.accepted.to_string() + "\n")
  builder.write_string("- Rejected rows: " + report.rejected.to_string() + "\n")
  builder.write_string(
    "- Acceptance ratio: " + import_acceptance_ratio(report).to_string() + "\n",
  )
  builder.write_string(
    "- Total amount: " + import_total_amount(report).to_string() + "\n",
  )
  if !report.issues.is_empty() {
    builder.write_string("\n### Issues\n\n")
    for line in import_issue_lines(report) {
      builder.write_string("- " + line + "\n")
    }
  }
  builder.to_string()
}

///|
pub struct TradeQuery {
  country : String?
  year : Int?
  code_prefix : String?
  minimum_amount : Double?
  maximum_amount : Double?
  limit : Int
} derive(Debug, Eq)

///|
pub fn trade_query(
  country : String?,
  year : Int?,
  code_prefix : String?,
  minimum_amount : Double?,
  maximum_amount : Double?,
  limit : Int,
) -> TradeQuery {
  { country, year, code_prefix, minimum_amount, maximum_amount, limit }
}

///|
pub fn empty_trade_query() -> TradeQuery {
  trade_query(None, None, None, None, None, 0)
}

///|
fn query_matches(record : TradeRecord, query : TradeQuery) -> Bool {
  if query.country is Some(country) && record.country != country {
    return false
  }
  if query.year is Some(year) && record.year != year {
    return false
  }
  if query.code_prefix is Some(prefix) && !code_is_prefix(prefix, record.code) {
    return false
  }
  if query.minimum_amount is Some(minimum) && record.amount < minimum {
    return false
  }
  if query.maximum_amount is Some(maximum) && record.amount > maximum {
    return false
  }
  true
}

///|
pub fn query_records(
  records : Array[TradeRecord],
  query : TradeQuery,
) -> Array[TradeRecord] {
  let output : Array[TradeRecord] = []
  for record in records {
    if query_matches(record, query) {
      output.push(record)
      if query.limit > 0 && output.length() >= query.limit {
        break
      }
    }
  }
  output
}

///|
pub fn query_report(
  report : TradeImportReport,
  query : TradeQuery,
) -> Array[TradeRecord] {
  query_records(report.records, query)
}

///|
pub fn query_total_amount(records : Array[TradeRecord]) -> Double {
  let mut total = 0.0
  for record in records {
    total += record.amount
  }
  total
}

///|
pub fn query_country_counts(
  records : Array[TradeRecord],
) -> Array[(String, Int)] {
  let output : Array[(String, Int)] = []
  for record in records {
    let mut found = false
    let mut index = 0
    while index < output.length() {
      if output[index].0 == record.country {
        output[index] = (record.country, output[index].1 + 1)
        found = true
        break
      }
      index += 1
    }
    if !found {
      output.push((record.country, 1))
    }
  }
  output
}

///|
pub fn query_year_counts(records : Array[TradeRecord]) -> Array[(Int, Int)] {
  let output : Array[(Int, Int)] = []
  for record in records {
    let mut found = false
    let mut index = 0
    while index < output.length() {
      if output[index].0 == record.year {
        output[index] = (record.year, output[index].1 + 1)
        found = true
        break
      }
      index += 1
    }
    if !found {
      output.push((record.year, 1))
    }
  }
  output
}

///|
pub fn query_sorted_by_amount(
  records : Array[TradeRecord],
  descending : Bool,
) -> Array[TradeRecord] {
  let output = records.copy()
  let mut i = 1
  while i < output.length() {
    let item = output[i]
    let mut j = i
    while j > 0 {
      let previous = output[j - 1]
      let should_move = if descending {
        previous.amount < item.amount
      } else {
        previous.amount > item.amount
      }
      if !should_move {
        break
      }
      output[j] = previous
      j -= 1
    }
    output[j] = item
    i += 1
  }
  output
}

///|
pub fn query_sorted_by_code(records : Array[TradeRecord]) -> Array[TradeRecord] {
  let output = records.copy()
  let mut i = 1
  while i < output.length() {
    let item = output[i]
    let mut j = i
    while j > 0 && output[j - 1].code > item.code {
      output[j] = output[j - 1]
      j -= 1
    }
    output[j] = item
    i += 1
  }
  output
}

///|
pub fn query_page(
  records : Array[TradeRecord],
  offset : Int,
  page_size : Int,
) -> Array[TradeRecord] {
  let output : Array[TradeRecord] = []
  if offset < 0 || page_size <= 0 {
    return output
  }
  let mut index = offset
  while index < records.length() && output.length() < page_size {
    output.push(records[index])
    index += 1
  }
  output
}

///|
pub fn records_to_csv(records : Array[TradeRecord]) -> CsvTable {
  let rows : Array[Array[String]] = []
  for record in records {
    rows.push([
      record.code,
      record.country,
      record.year.to_string(),
      record.amount.to_string(),
    ])
  }
  csv_table(["code", "country", "year", "amount"], rows)
}

///|
pub fn report_to_csv(report : TradeImportReport) -> String {
  csv_render(records_to_csv(report.records), csv_default_options())
}
