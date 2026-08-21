///|
test "normalization and hierarchy boundaries" {
  let empty = normalize_code("   ", default_normalization_policy())
  assert_true(!normalization_is_valid(empty))
  assert_eq(code_prefix("010123", 0), "")
  assert_eq(code_prefix("010123", 3), "010")
  assert_true(code_is_prefix("010", "010123"))
  assert_true(!code_is_prefix("011", "010123"))
  assert_eq(code_parent_at("010123", 4), Some("0101"))
  assert_eq(code_parent_at("010123", 0), None)
}

///|
test "catalog merge and validation" {
  let system = classification_system("HS", "Harmonized System")
  let version = classification_version(system, "2022", 2022)
  let root = product_code(
    version,
    "01",
    "Animals",
    2,
    active_code_state(),
    None,
  )
  let child = product_code(
    version,
    "0101",
    "Horses",
    4,
    active_code_state(),
    Some("01"),
  )
  let catalog = catalog_add_product(
    catalog_add_version(catalog_add_system(empty_catalog(), system), version),
    root,
  )
  let complete = catalog_add_product(catalog, child)
  assert_true(catalog_is_valid(complete))
  assert_eq(catalog_children(complete, "01").length(), 1)
  assert_eq(catalog_count_by_level(complete, 4), 1)
  assert_eq(catalog_snapshot(complete), "systems=1,versions=1,products=2")
  assert_eq(catalog_merge(complete, complete).products.length(), 2)
}

///|
test "quality audit catches duplicates and unnormalized weights" {
  let first = concordance_rule(
    "A",
    [mapping_target("B", 0.8), mapping_target("C", 0.8)],
    exact_confidence(),
    "",
  ) catch {
    err => abort(err.to_string())
  }
  let duplicate = concordance_rule(
    "A",
    [mapping_target("B", 1.0)],
    exact_confidence(),
    "duplicate",
  ) catch {
    err => abort(err.to_string())
  }
  let summary = quality_summary([first, duplicate])
  assert_true(quality_has_errors(summary))
  assert_true(quality_warning_count(summary) >= 2)
  assert_true(quality_score(summary) < 1.0)
}

///|
test "analytics handles empty, singleton and weighted inputs" {
  assert_eq(sum([]), 0.0)
  assert_eq(mean([]), 0.0)
  assert_eq(quantile([], 0.5), None)
  assert_eq(quantile([4.0], 0.5), Some(4.0))
  let summary = summarize([1.0, 2.0, 3.0])
  assert_eq(summary.count, 3)
  assert_eq(summary.mean, 2.0)
  assert_eq(moving_sum([1.0, 2.0, 3.0], 2), [3.0, 5.0])
  let weighted = [
    weighted_observation("A", 10.0, 0.25),
    weighted_observation("B", 20.0, 0.75),
  ]
  assert_eq(weight_total(weighted), 1.0)
  assert_eq(weighted_mean(weighted), 17.5)
}

///|
test "version diff classifies additions removals and metadata changes" {
  let system = classification_system("HS", "Harmonized System")
  let before = classification_version(system, "2017", 2017)
  let after = classification_version(system, "2022", 2022)
  let old = [
    product_code(before, "01", "Animals", 2, active_code_state(), None),
  ]
  let new = [
    product_code(after, "01", "Live animals", 2, active_code_state(), None),
    product_code(after, "02", "Vegetables", 2, active_code_state(), None),
  ]
  let diff = diff_versions(old, new, before, after)
  assert_eq(change_count(diff, changed_change_kind()), 1)
  assert_eq(change_count(diff, added_change_kind()), 1)
  assert_eq(change_count(diff, removed_change_kind()), 0)
  assert_true(diff_has_breaking_changes(diff))
}
