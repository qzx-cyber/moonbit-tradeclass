///|
pub enum MappingConfidence {
  Exact
  Approximate
  Unmappable
} derive(Debug, Eq)

///|
pub enum CodeState {
  Active
  Retired
  Split
  Merged
} derive(Debug, Eq)

///|
pub struct ClassificationSystem {
  id : String
  name : String
} derive(Debug, Eq)

///|
pub struct ClassificationVersion {
  system : ClassificationSystem
  label : String
  year : Int
} derive(Debug, Eq)

///|
pub struct ProductCode {
  version : ClassificationVersion
  code : String
  title : String
  level : Int
  state : CodeState
  parent : String?
} derive(Debug, Eq)

///|
pub struct MappingTarget {
  code : String
  weight : Double
} derive(Debug, Eq)

///|
pub struct ConcordanceRule {
  from : String
  to : Array[MappingTarget]
  confidence : MappingConfidence
  reason : String
} derive(Debug, Eq)

///|
pub struct MappingResult {
  input : String
  targets : Array[MappingTarget]
  confidence : MappingConfidence
  reason : String
} derive(Debug, Eq)

///|
pub fn classification_system(
  id : String,
  name : String,
) -> ClassificationSystem {
  { id, name }
}

///|
pub fn exact_confidence() -> MappingConfidence {
  Exact
}

///|
pub fn approximate_confidence() -> MappingConfidence {
  Approximate
}

///|
pub fn unmappable_confidence() -> MappingConfidence {
  Unmappable
}

///|
pub fn active_code_state() -> CodeState {
  Active
}

///|
pub fn retired_code_state() -> CodeState {
  Retired
}

///|
pub fn split_code_state() -> CodeState {
  Split
}

///|
pub fn merged_code_state() -> CodeState {
  Merged
}

///|
pub fn classification_version(
  system : ClassificationSystem,
  label : String,
  year : Int,
) -> ClassificationVersion {
  { system, label, year }
}

///|
pub fn product_code(
  version : ClassificationVersion,
  code : String,
  title : String,
  level : Int,
  state : CodeState,
  parent : String?,
) -> ProductCode {
  { version, code, title, level, state, parent }
}

///|
pub fn mapping_target(code : String, weight : Double) -> MappingTarget raise {
  if code.trim() == "" {
    fail("mapping target code cannot be empty")
  }
  if weight < 0.0 {
    fail("mapping target weight cannot be negative")
  }
  { code, weight }
}

///|
pub fn concordance_rule(
  from : String,
  to : Array[MappingTarget],
  confidence : MappingConfidence,
  reason : String,
) -> ConcordanceRule raise {
  if from.trim() == "" {
    fail("rule source code cannot be empty")
  }
  if to.is_empty() && confidence != Unmappable {
    fail("only unmappable rules may have no targets")
  }
  { from, to, confidence, reason }
}

///|
pub fn mapping_result(
  input : String,
  targets : Array[MappingTarget],
  confidence : MappingConfidence,
  reason : String,
) -> MappingResult {
  { input, targets, confidence, reason }
}

///|
pub fn confidence_is_usable(confidence : MappingConfidence) -> Bool {
  match confidence {
    Exact | Approximate => true
    Unmappable => false
  }
}

///|
pub fn code_state_is_live(state : CodeState) -> Bool {
  match state {
    Active | Split | Merged => true
    Retired => false
  }
}
