///|
pub enum ChangeKind {
  AddedCode
  RemovedCode
  RetainedCode
  ChangedCode
} derive(Debug, Eq)

///|
pub struct CodeChange {
  code : String
  kind : ChangeKind
  before : ProductCode?
  after : ProductCode?
  detail : String
} derive(Debug, Eq)

///|
pub struct VersionDiff {
  from : ClassificationVersion
  to : ClassificationVersion
  changes : Array[CodeChange]
} derive(Debug)

///|
pub fn code_change(
  code : String,
  kind : ChangeKind,
  before : ProductCode?,
  after : ProductCode?,
  detail : String,
) -> CodeChange {
  { code, kind, before, after, detail }
}

///|
pub fn added_change_kind() -> ChangeKind {
  AddedCode
}

///|
pub fn removed_change_kind() -> ChangeKind {
  RemovedCode
}

///|
pub fn changed_change_kind() -> ChangeKind {
  ChangedCode
}

///|
pub fn diff_versions(
  left : Array[ProductCode],
  right : Array[ProductCode],
  from : ClassificationVersion,
  to : ClassificationVersion,
) -> VersionDiff {
  let changes : Array[CodeChange] = []
  for product in left {
    match find_product_code(right, product.code) {
      None =>
        changes.push(
          code_change(
            product.code,
            RemovedCode,
            Some(product),
            None,
            "not present in destination",
          ),
        )
      Some(other) =>
        if product.title != other.title ||
          product.level != other.level ||
          product.state != other.state ||
          product.parent != other.parent {
          changes.push(
            code_change(
              product.code,
              ChangedCode,
              Some(product),
              Some(other),
              "metadata changed",
            ),
          )
        } else {
          changes.push(
            code_change(
              product.code,
              RetainedCode,
              Some(product),
              Some(other),
              "unchanged",
            ),
          )
        }
    }
  }
  for product in right {
    if find_product_code(left, product.code) is None {
      changes.push(
        code_change(
          product.code,
          AddedCode,
          None,
          Some(product),
          "new in destination",
        ),
      )
    }
  }
  { from, to, changes }
}

///|
fn find_product_code(
  products : Array[ProductCode],
  code : String,
) -> ProductCode? {
  for product in products {
    if product.code == code {
      return Some(product)
    }
  }
  None
}

///|
pub fn change_count(diff : VersionDiff, kind : ChangeKind) -> Int {
  let mut count = 0
  for change in diff.changes {
    if change.kind == kind {
      count += 1
    }
  }
  count
}

///|
pub fn added_codes(diff : VersionDiff) -> Array[String] {
  change_codes(diff, AddedCode)
}

///|
pub fn removed_codes(diff : VersionDiff) -> Array[String] {
  change_codes(diff, RemovedCode)
}

///|
pub fn retained_codes(diff : VersionDiff) -> Array[String] {
  change_codes(diff, RetainedCode)
}

///|
pub fn changed_codes(diff : VersionDiff) -> Array[String] {
  change_codes(diff, ChangedCode)
}

///|
fn change_codes(diff : VersionDiff, kind : ChangeKind) -> Array[String] {
  let result : Array[String] = []
  for change in diff.changes {
    if change.kind == kind {
      result.push(change.code)
    }
  }
  sort_codes_lexical(result)
}

///|
pub fn change_kind_name(kind : ChangeKind) -> String {
  match kind {
    AddedCode => "added"
    RemovedCode => "removed"
    RetainedCode => "retained"
    ChangedCode => "changed"
  }
}

///|
pub fn diff_summary(diff : VersionDiff) -> String {
  "from=" +
  diff.from.label +
  ",to=" +
  diff.to.label +
  ",added=" +
  change_count(diff, AddedCode).to_string() +
  ",removed=" +
  change_count(diff, RemovedCode).to_string() +
  ",retained=" +
  change_count(diff, RetainedCode).to_string() +
  ",changed=" +
  change_count(diff, ChangedCode).to_string()
}

///|
pub fn diff_change_lines(diff : VersionDiff) -> Array[String] {
  let lines : Array[String] = []
  for change in diff.changes {
    lines.push(
      change_kind_name(change.kind) + ":" + change.code + ":" + change.detail,
    )
  }
  lines
}

///|
pub fn diff_change_ratio(diff : VersionDiff, kind : ChangeKind) -> Double {
  if diff.changes.is_empty() {
    0.0
  } else {
    change_count(diff, kind).to_double() / diff.changes.length().to_double()
  }
}

///|
pub fn diff_has_breaking_changes(diff : VersionDiff) -> Bool {
  change_count(diff, RemovedCode) > 0 || change_count(diff, ChangedCode) > 0
}

///|
pub fn diff_level_counts(
  diff : VersionDiff,
  kind : ChangeKind,
) -> Array[(Int, Int)] {
  let result : Array[(Int, Int)] = []
  for change in diff.changes {
    if change.kind != kind {
      continue
    }
    let level = match (change.before, change.after) {
      (Some(before), _) => before.level
      (_, Some(after)) => after.level
      _ => 0
    }
    let mut found = false
    let mut i = 0
    while i < result.length() {
      if result[i].0 == level {
        result[i] = (level, result[i].1 + 1)
        found = true
        break
      }
      i += 1
    }
    if !found {
      result.push((level, 1))
    }
  }
  result
}
