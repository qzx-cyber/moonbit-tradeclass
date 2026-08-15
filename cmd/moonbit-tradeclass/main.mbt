///|
fn main {
  let target = @tradeclass.mapping_target("SITC001", 1.0) catch {
    err => abort(err.to_string())
  }
  let rule = @tradeclass.concordance_rule(
    "0101",
    [target],
    @tradeclass.exact_confidence(),
    "built-in demonstration",
  ) catch {
    err => abort(err.to_string())
  }
  let result = @tradeclass.map_code(@tradeclass.concordance([rule]), "0101")
  println("moonbit-tradeclass map demo")
  println("0101 -> " + result.targets[0].code)
  println("Use the library API to connect licensed CSV/JSON datasets.")
}
