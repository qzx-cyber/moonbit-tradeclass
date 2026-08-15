# Quickstart

```mbt nocheck
let book = concordance([
  concordance_rule(
    "0101",
    [mapping_target("SITC001", 1.0)],
    exact_confidence(),
    "fixture",
  ),
])
let result = map_code(book, "0101")
debug_inspect(result.confidence)
```

For a real dataset, load records in an application layer, build rules from a licensed source, call `map_code`, and pass accepted `TradeRecord` values to `aggregate`.
