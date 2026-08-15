///|
pub struct Concordance {
  rules : Array[ConcordanceRule]
} derive(Debug)

///|
pub fn concordance(rules : Array[ConcordanceRule]) -> Concordance {
  { rules, }
}

///|
fn Concordance::rule_for(self : Concordance, code : String) -> ConcordanceRule? {
  for rule in self.rules {
    if rule.from == code {
      return Some(rule)
    }
  }
  None
}

///|
fn merge_confidence(
  left : MappingConfidence,
  right : MappingConfidence,
) -> MappingConfidence {
  match (left, right) {
    (Unmappable, _) | (_, Unmappable) => Unmappable
    (Approximate, _) | (_, Approximate) => Approximate
    _ => Exact
  }
}

///|
fn map_inner(
  book : Concordance,
  code : String,
  seen : Array[String],
  confidence : MappingConfidence,
) -> MappingResult {
  if seen.contains(code) {
    return mapping_result(code, [], Unmappable, "cycle detected")
  }
  let next_seen = seen.copy()
  next_seen.push(code)
  match book.rule_for(code) {
    None => mapping_result(code, [], Unmappable, "no concordance rule")
    Some(rule) => {
      let combined = merge_confidence(confidence, rule.confidence)
      if rule.confidence == Unmappable {
        mapping_result(code, [], Unmappable, rule.reason)
      } else {
        let targets : Array[MappingTarget] = []
        let reason = rule.reason
        for target in rule.to {
          match book.rule_for(target.code) {
            None => targets.push(target)
            Some(_) => {
              let nested = map_inner(book, target.code, next_seen, combined)
              if nested.confidence == Unmappable {
                targets.push(target)
              } else {
                for nested_target in nested.targets {
                  targets.push({
                    code: nested_target.code,
                    weight: target.weight * nested_target.weight,
                  })
                }
              }
            }
          }
        }
        mapping_result(code, targets, combined, reason)
      }
    }
  }
}

///|
pub fn map_code(book : Concordance, code : String) -> MappingResult {
  map_inner(book, code, [], Exact)
}
