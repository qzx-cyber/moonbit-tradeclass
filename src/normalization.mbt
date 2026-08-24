///|
pub enum NormalizationIssue {
  EmptyInput
  WhitespaceOnly
  InvalidCharacter
  NonCanonicalWidth
  UnexpectedSeparator
} derive(Debug, Eq)

///|
pub struct NormalizationReport {
  original : String
  normalized : String
  issues : Array[NormalizationIssue]
  changed : Bool
} derive(Debug, Eq)

///|
pub struct NormalizationPolicy {
  trim : Bool
  uppercase : Bool
  remove_spaces : Bool
  remove_dashes : Bool
  remove_dots : Bool
  allow_letters : Bool
  allow_digits : Bool
} derive(Debug, Eq)

///|
pub fn default_normalization_policy() -> NormalizationPolicy {
  {
    trim: true,
    uppercase: true,
    remove_spaces: true,
    remove_dashes: true,
    remove_dots: false,
    allow_letters: true,
    allow_digits: true,
  }
}

///|
pub fn strict_numeric_policy() -> NormalizationPolicy {
  {
    trim: true,
    uppercase: false,
    remove_spaces: true,
    remove_dashes: false,
    remove_dots: false,
    allow_letters: false,
    allow_digits: true,
  }
}

///|
fn is_ascii_digit(ch : Char) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_ascii_lower(ch : Char) -> Bool {
  ch >= 'a' && ch <= 'z'
}

///|
fn is_ascii_upper(ch : Char) -> Bool {
  ch >= 'A' && ch <= 'Z'
}

///|
fn ascii_upper(ch : Char) -> Char {
  match ch {
    'a' => 'A'
    'b' => 'B'
    'c' => 'C'
    'd' => 'D'
    'e' => 'E'
    'f' => 'F'
    'g' => 'G'
    'h' => 'H'
    'i' => 'I'
    'j' => 'J'
    'k' => 'K'
    'l' => 'L'
    'm' => 'M'
    'n' => 'N'
    'o' => 'O'
    'p' => 'P'
    'q' => 'Q'
    'r' => 'R'
    's' => 'S'
    't' => 'T'
    'u' => 'U'
    'v' => 'V'
    'w' => 'W'
    'x' => 'X'
    'y' => 'Y'
    'z' => 'Z'
    _ => ch
  }
}

///|
fn keep_character(ch : Char, policy : NormalizationPolicy) -> Bool {
  if is_ascii_digit(ch) {
    return policy.allow_digits
  }
  if is_ascii_lower(ch) || is_ascii_upper(ch) {
    return policy.allow_letters
  }
  false
}

///|
pub fn normalize_code(
  input : String,
  policy : NormalizationPolicy,
) -> NormalizationReport {
  let issues : Array[NormalizationIssue] = []
  if input == "" {
    issues.push(EmptyInput)
  }
  let source = if policy.trim { input.trim().to_owned() } else { input }
  if source == "" && input != "" {
    issues.push(WhitespaceOnly)
  }
  let output : StringBuilder = StringBuilder()
  for ch in source {
    if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
      if !policy.remove_spaces {
        output.write_char(ch)
      }
      continue
    }
    if ch == '-' {
      if !policy.remove_dashes {
        output.write_char(ch)
      } else {
        issues.push(UnexpectedSeparator)
      }
      continue
    }
    if ch == '.' {
      if !policy.remove_dots {
        output.write_char(ch)
      } else {
        issues.push(UnexpectedSeparator)
      }
      continue
    }
    if !keep_character(ch, policy) {
      issues.push(InvalidCharacter)
    } else {
      let canonical = if policy.uppercase { ascii_upper(ch) } else { ch }
      if canonical != ch {
        issues.push(NonCanonicalWidth)
      }
      output.write_char(canonical)
    }
  }
  let normalized = output.to_string()
  { original: input, normalized, issues, changed: input != normalized }
}

///|
pub fn normalize_code_or_empty(input : String) -> String {
  normalize_code(input, default_normalization_policy()).normalized
}

///|
pub fn normalization_is_valid(report : NormalizationReport) -> Bool {
  report.issues.is_empty() && report.normalized != ""
}

///|
pub fn normalization_issue_count(report : NormalizationReport) -> Int {
  report.issues.length()
}

///|
pub fn normalize_codes(
  inputs : Array[String],
  policy : NormalizationPolicy,
) -> Array[NormalizationReport] {
  let reports : Array[NormalizationReport] = []
  for input in inputs {
    reports.push(normalize_code(input, policy))
  }
  reports
}

///|
pub fn canonical_code_key(
  system : String,
  version : String,
  code : String,
) -> String {
  system.trim().to_owned().to_upper() +
  ":" +
  version.trim().to_owned() +
  ":" +
  normalize_code_or_empty(code)
}

///|
pub fn code_prefix(code : String, length : Int) -> String {
  if length <= 0 {
    return ""
  }
  let result : StringBuilder = StringBuilder()
  let mut count = 0
  for ch in code {
    if count >= length {
      break
    }
    result.write_char(ch)
    count += 1
  }
  result.to_string()
}

///|
pub fn code_depth(code : String) -> Int {
  let mut count = 0
  for _ in code {
    count += 1
  }
  count
}

///|
pub fn code_is_prefix(parent : String, child : String) -> Bool {
  let p = normalize_code_or_empty(parent)
  let c = normalize_code_or_empty(child)
  p != "" &&
  c != "" &&
  p.length() <= c.length() &&
  code_prefix(c, p.length()) == p
}

///|
pub fn code_parent_at(code : String, level : Int) -> String? {
  let normalized = normalize_code_or_empty(code)
  if level <= 0 || level > normalized.length() {
    None
  } else {
    Some(code_prefix(normalized, level))
  }
}

///|
pub fn code_levels(code : String) -> Array[String] {
  let normalized = normalize_code_or_empty(code)
  let levels : Array[String] = []
  let mut index = 1
  while index <= normalized.length() {
    levels.push(code_prefix(normalized, index))
    index += 1
  }
  levels
}

///|
pub fn codes_share_prefix(left : String, right : String, length : Int) -> Bool {
  if length <= 0 {
    return true
  }
  code_prefix(normalize_code_or_empty(left), length) ==
  code_prefix(normalize_code_or_empty(right), length)
}

///|
pub fn sort_codes_lexical(codes : Array[String]) -> Array[String] {
  let output = codes.copy()
  let mut i = 0
  while i < output.length() {
    let mut j = i + 1
    while j < output.length() {
      if output[j] < output[i] {
        let temporary = output[i]
        output[i] = output[j]
        output[j] = temporary
      }
      j += 1
    }
    i += 1
  }
  output
}
