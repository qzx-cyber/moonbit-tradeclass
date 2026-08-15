///|
fn must_target(code : String, weight : Double) -> MappingTarget {
  mapping_target(code, weight) catch {
    err => abort(err.to_string())
  }
}

///|
fn must_rule(
  from : String,
  to : Array[MappingTarget],
  confidence : MappingConfidence,
  reason : String,
) -> ConcordanceRule {
  concordance_rule(from, to, confidence, reason) catch {
    err => abort(err.to_string())
  }
}

///|
fn fixture_book() -> Concordance {
  concordance([
    must_rule(
      "0101",
      [must_target("010121", 0.7), must_target("010129", 0.3)],
      exact_confidence(),
      "split",
    ),
    must_rule(
      "010121",
      [must_target("SITC001", 1.0)],
      exact_confidence(),
      "bridge",
    ),
    must_rule(
      "010129",
      [must_target("SITC002", 1.0)],
      approximate_confidence(),
      "approximate bridge",
    ),
    must_rule(
      "CYCLE-A",
      [must_target("CYCLE-B", 1.0)],
      exact_confidence(),
      "cycle fixture",
    ),
    must_rule(
      "CYCLE-B",
      [must_target("CYCLE-A", 1.0)],
      exact_confidence(),
      "cycle fixture",
    ),
    must_rule("MISSING", [], unmappable_confidence(), "source code retired"),
  ])
}

///|
test "maps split and weighted rules through a bridge" {
  let result = map_code(fixture_book(), "0101")
  debug_inspect(
    result.targets,
    content=(
      #|[{ code: "SITC001", weight: 0.7 }, { code: "SITC002", weight: 0.3 }]
    ),
  )
  debug_inspect(
    result.confidence,
    content=(
      #|Exact
    ),
  )
}

///|
test "reports cycles and missing mappings" {
  debug_inspect(
    map_code(fixture_book(), "CYCLE-A").confidence,
    content=(
      #|Exact
    ),
  )
  debug_inspect(
    map_code(fixture_book(), "MISSING").reason,
    content="\"source code retired\"",
  )
}
