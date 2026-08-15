///|
test "constructs a weighted split rule" {
  let hs = classification_system("HS", "Harmonized System")
  let v = classification_version(hs, "2022", 2022)
  let code = product_code(
    v,
    "0101",
    "Live horses",
    4,
    active_code_state(),
    None,
  )
  debug_inspect(code.code, content="\"0101\"")
  let rule = concordance_rule(
    "0101",
    [mapping_target("010121", 0.7), mapping_target("010129", 0.3)],
    exact_confidence(),
    "official concordance fixture",
  )
  debug_inspect(rule.to.length(), content="2")
}

///|
test "rejects negative mapping weights" {
  try mapping_target("0101", -0.1) catch {
    err =>
      debug_inspect(
        err,
        content=(
          #|Failure("src/model.mbt:131:5-131:53@qzx-cyber/moonbit-tradeclass FAILED: mapping target weight cannot be negative")
        ),
      )
  } noraise {
    _ => fail("expected negative weight to fail")
  }
}
