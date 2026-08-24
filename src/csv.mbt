///|
/// A small, deterministic CSV layer for data ingestion boundaries.
///
/// The core library deliberately does not depend on a filesystem or a
/// network client. Callers can read bytes in their application layer and pass
/// the resulting text to this module. Parsing is stateful enough to handle
/// quoted delimiters, escaped quotes, and CRLF input while keeping the public
/// data model independent from a particular storage system.

///|
pub struct CsvOptions {
  delimiter : Char
  quote : Char
  trim_unquoted : Bool
  skip_blank_rows : Bool
} derive(Debug, Eq)

///|
pub fn csv_options(
  delimiter : Char,
  quote : Char,
  trim_unquoted : Bool,
  skip_blank_rows : Bool,
) -> CsvOptions {
  { delimiter, quote, trim_unquoted, skip_blank_rows }
}

///|
pub fn csv_default_options() -> CsvOptions {
  csv_options(',', '"', true, true)
}

///|
pub struct CsvIssue {
  row : Int
  column : Int
  message : String
} derive(Debug, Eq)

///|
pub fn csv_issue(row : Int, column : Int, message : String) -> CsvIssue {
  { row, column, message }
}

///|
pub struct CsvTable {
  headers : Array[String]
  rows : Array[Array[String]]
} derive(Debug, Eq)

///|
pub fn csv_table(
  headers : Array[String],
  rows : Array[Array[String]],
) -> CsvTable {
  { headers, rows }
}

///|
pub enum CsvParseResult {
  CsvOk(CsvTable)
  CsvInvalid(Array[CsvIssue])
} derive(Debug, Eq)

///|
fn csv_is_blank_row(row : Array[String]) -> Bool {
  if row.length() != 1 {
    return false
  }
  row[0].trim() == ""
}

///|
fn csv_normalize_field(
  value : String,
  options : CsvOptions,
  quoted : Bool,
) -> String {
  if quoted || !options.trim_unquoted {
    value
  } else {
    value.trim().to_owned()
  }
}

///|
fn csv_push_field(
  fields : Array[String],
  builder : StringBuilder,
  options : CsvOptions,
  quoted : Bool,
) -> StringBuilder {
  fields.push(csv_normalize_field(builder.to_string(), options, quoted))
  StringBuilder()
}

///|
fn csv_push_row(
  rows : Array[Array[String]],
  fields : Array[String],
  options : CsvOptions,
) -> Unit {
  if options.skip_blank_rows && csv_is_blank_row(fields) {
    return
  }
  rows.push(fields.copy())
}

///|
fn csv_validate_widths(rows : Array[Array[String]]) -> Array[CsvIssue] {
  let issues : Array[CsvIssue] = []
  if rows.is_empty() {
    issues.push(csv_issue(1, 1, "CSV input has no rows"))
    return issues
  }
  let expected = rows[0].length()
  if expected == 0 {
    issues.push(csv_issue(1, 1, "CSV header is empty"))
    return issues
  }
  let mut row_number = 2
  for row in rows[1:] {
    if row.length() != expected {
      issues.push(
        csv_issue(
          row_number,
          row.length() + 1,
          "row has " +
          row.length().to_string() +
          " fields; expected " +
          expected.to_string(),
        ),
      )
    }
    row_number += 1
  }
  issues
}

///|
/// Parse CSV text into a header and rectangular data rows.
///
/// A malformed quote or an inconsistent row width is returned as a structured
/// issue instead of aborting the host application. This makes it possible for
/// batch importers to report all bad rows in one response.
pub fn csv_parse(text : String, options : CsvOptions) -> CsvParseResult {
  let rows : Array[Array[String]] = []
  let mut fields : Array[String] = []
  let mut builder = StringBuilder()
  let mut quoted = false
  let mut quote_closed = false
  let mut field_started = false
  let mut row_number = 1
  let mut column_number = 1
  for ch in text {
    if quoted {
      if ch == options.quote {
        quoted = false
        quote_closed = true
      } else {
        builder.write_char(ch)
      }
      continue
    }
    if quote_closed {
      if ch == options.quote {
        builder.write_char(ch)
        quoted = true
        quote_closed = false
      } else if ch == options.delimiter {
        builder = csv_push_field(fields, builder, options, true)
        field_started = false
        quote_closed = false
        column_number += 1
      } else if ch == '\n' {
        builder = csv_push_field(fields, builder, options, true)
        csv_push_row(rows, fields, options)
        fields = []
        row_number += 1
        column_number = 1
        field_started = false
        quote_closed = false
      } else if ch == '\r' {
        continue
      } else if ch == ' ' || ch == '\t' {
        continue
      } else {
        return CsvInvalid([
          csv_issue(
            row_number, column_number, "characters after a closing quote are not allowed",
          ),
        ])
      }
      continue
    }
    if ch == options.delimiter {
      builder = csv_push_field(fields, builder, options, false)
      field_started = false
      column_number += 1
    } else if ch == '\n' {
      builder = csv_push_field(fields, builder, options, false)
      csv_push_row(rows, fields, options)
      fields = []
      row_number += 1
      column_number = 1
      field_started = false
    } else if ch == '\r' {
      continue
    } else if ch == options.quote {
      if field_started || builder.to_string() != "" {
        return CsvInvalid([
          csv_issue(
            row_number, column_number, "a quote may only open an empty field",
          ),
        ])
      }
      quoted = true
      field_started = true
    } else {
      builder.write_char(ch)
      field_started = true
    }
  }
  if quoted {
    return CsvInvalid([
      csv_issue(row_number, column_number, "unterminated quoted field"),
    ])
  }
  if quote_closed ||
    field_started ||
    !fields.is_empty() ||
    builder.to_string() != "" {
    builder = csv_push_field(fields, builder, options, quote_closed)
    csv_push_row(rows, fields, options)
  }
  let width_issues = csv_validate_widths(rows)
  if !width_issues.is_empty() {
    return CsvInvalid(width_issues)
  }
  let headers = rows[0].copy()
  let data : Array[Array[String]] = []
  for row in rows[1:] {
    data.push(row)
  }
  CsvOk(csv_table(headers, data))
}

///|
pub fn csv_header_index(table : CsvTable, name : String) -> Int? {
  let wanted = name.trim().to_lower()
  let mut index = 0
  for header in table.headers {
    if header.trim().to_lower() == wanted {
      return Some(index)
    }
    index += 1
  }
  None
}

///|
pub fn csv_require_columns(
  table : CsvTable,
  names : Array[String],
) -> Array[CsvIssue] {
  let issues : Array[CsvIssue] = []
  for name in names {
    if csv_header_index(table, name) is None {
      issues.push(csv_issue(1, 0, "missing required column: " + name))
    }
  }
  issues
}

///|
pub fn csv_cell(table : CsvTable, row : Int, column : Int) -> String? {
  if row < 0 || row >= table.rows.length() || column < 0 {
    return None
  }
  let values = table.rows[row]
  if column >= values.length() {
    None
  } else {
    Some(values[column])
  }
}

///|
pub fn csv_column(table : CsvTable, name : String) -> Array[String] {
  let output : Array[String] = []
  match csv_header_index(table, name) {
    None => output
    Some(index) => {
      for row in table.rows {
        if index < row.length() {
          output.push(row[index])
        }
      }
      output
    }
  }
}

///|
pub fn csv_select_columns(
  table : CsvTable,
  names : Array[String],
) -> CsvParseResult {
  let indexes : Array[Int] = []
  let issues : Array[CsvIssue] = []
  for name in names {
    match csv_header_index(table, name) {
      None => issues.push(csv_issue(1, 0, "missing column: " + name))
      Some(index) => indexes.push(index)
    }
  }
  if !issues.is_empty() {
    return CsvInvalid(issues)
  }
  let rows : Array[Array[String]] = []
  for row in table.rows {
    let selected : Array[String] = []
    for index in indexes {
      selected.push(row[index])
    }
    rows.push(selected)
  }
  CsvOk(csv_table(names.copy(), rows))
}

///|
fn csv_needs_quote(value : String, options : CsvOptions) -> Bool {
  for ch in value {
    if ch == options.delimiter ||
      ch == options.quote ||
      ch == '\n' ||
      ch == '\r' {
      return true
    }
  }
  false
}

///|
fn csv_escape(value : String, options : CsvOptions) -> String {
  if !csv_needs_quote(value, options) {
    return value
  }
  let builder = StringBuilder()
  builder.write_char(options.quote)
  for ch in value {
    if ch == options.quote {
      builder.write_char(options.quote)
    }
    builder.write_char(ch)
  }
  builder.write_char(options.quote)
  builder.to_string()
}

///|
pub fn csv_render(table : CsvTable, options : CsvOptions) -> String {
  let builder = StringBuilder()
  let mut first = true
  for header in table.headers {
    if !first {
      builder.write_char(options.delimiter)
    }
    builder.write_string(csv_escape(header, options))
    first = false
  }
  builder.write_char('\n')
  for row in table.rows {
    first = true
    for value in row {
      if !first {
        builder.write_char(options.delimiter)
      }
      builder.write_string(csv_escape(value, options))
      first = false
    }
    builder.write_char('\n')
  }
  builder.to_string()
}

///|
pub fn csv_render_row(values : Array[String], options : CsvOptions) -> String {
  let builder = StringBuilder()
  let mut first = true
  for value in values {
    if !first {
      builder.write_char(options.delimiter)
    }
    builder.write_string(csv_escape(value, options))
    first = false
  }
  builder.to_string()
}

///|
pub fn csv_table_row_count(table : CsvTable) -> Int {
  table.rows.length()
}

///|
pub fn csv_table_column_count(table : CsvTable) -> Int {
  table.headers.length()
}

///|
pub fn csv_issue_count(result : CsvParseResult) -> Int {
  match result {
    CsvOk(_) => 0
    CsvInvalid(issues) => issues.length()
  }
}

///|
pub fn csv_is_valid(result : CsvParseResult) -> Bool {
  match result {
    CsvOk(_) => true
    CsvInvalid(_) => false
  }
}

///|
pub fn csv_headers(table : CsvTable) -> Array[String] {
  table.headers.copy()
}

///|
pub fn csv_rows(table : CsvTable) -> Array[Array[String]] {
  let output : Array[Array[String]] = []
  for row in table.rows {
    output.push(row.copy())
  }
  output
}
