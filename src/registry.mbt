///|
pub struct ClassificationCatalog {
  systems : Array[ClassificationSystem]
  versions : Array[ClassificationVersion]
  products : Array[ProductCode]
} derive(Debug)

///|
pub fn empty_catalog() -> ClassificationCatalog {
  { systems: [], versions: [], products: [] }
}

///|
pub fn catalog_add_system(
  catalog : ClassificationCatalog,
  system : ClassificationSystem,
) -> ClassificationCatalog {
  let result = {
    systems: catalog.systems.copy(),
    versions: catalog.versions.copy(),
    products: catalog.products.copy(),
  }
  if catalog_find_system(result, system.id) is None {
    result.systems.push(system)
  }
  result
}

///|
pub fn catalog_add_version(
  catalog : ClassificationCatalog,
  version : ClassificationVersion,
) -> ClassificationCatalog {
  let result = {
    systems: catalog.systems.copy(),
    versions: catalog.versions.copy(),
    products: catalog.products.copy(),
  }
  if catalog_find_version(result, version.system.id, version.label) is None {
    result.versions.push(version)
  }
  result
}

///|
pub fn catalog_add_product(
  catalog : ClassificationCatalog,
  product : ProductCode,
) -> ClassificationCatalog {
  let result = {
    systems: catalog.systems.copy(),
    versions: catalog.versions.copy(),
    products: catalog.products.copy(),
  }
  if catalog_find_product(
      result,
      product.version.system.id,
      product.version.label,
      product.code,
    )
    is None {
    result.products.push(product)
  }
  result
}

///|
pub fn catalog_add_products(
  catalog : ClassificationCatalog,
  products : Array[ProductCode],
) -> ClassificationCatalog {
  let mut result = catalog
  for product in products {
    result = catalog_add_product(result, product)
  }
  result
}

///|
pub fn catalog_find_system(
  catalog : ClassificationCatalog,
  id : String,
) -> ClassificationSystem? {
  for system in catalog.systems {
    if system.id == id {
      return Some(system)
    }
  }
  None
}

///|
pub fn catalog_find_version(
  catalog : ClassificationCatalog,
  system_id : String,
  label : String,
) -> ClassificationVersion? {
  for version in catalog.versions {
    if version.system.id == system_id && version.label == label {
      return Some(version)
    }
  }
  None
}

///|
pub fn catalog_find_product(
  catalog : ClassificationCatalog,
  system_id : String,
  version_label : String,
  code : String,
) -> ProductCode? {
  for product in catalog.products {
    if product.version.system.id == system_id &&
      product.version.label == version_label &&
      product.code == code {
      return Some(product)
    }
  }
  None
}

///|
pub fn catalog_products_for_version(
  catalog : ClassificationCatalog,
  system_id : String,
  version_label : String,
) -> Array[ProductCode] {
  let products : Array[ProductCode] = []
  for product in catalog.products {
    if product.version.system.id == system_id &&
      product.version.label == version_label {
      products.push(product)
    }
  }
  products
}

///|
pub fn catalog_children(
  catalog : ClassificationCatalog,
  parent : String,
) -> Array[ProductCode] {
  let children : Array[ProductCode] = []
  for product in catalog.products {
    match product.parent {
      Some(value) => if value == parent { children.push(product) }
      None => ()
    }
  }
  children
}

///|
pub fn catalog_live_products(
  catalog : ClassificationCatalog,
) -> Array[ProductCode] {
  let products : Array[ProductCode] = []
  for product in catalog.products {
    if code_state_is_live(product.state) {
      products.push(product)
    }
  }
  products
}

///|
pub fn catalog_retired_products(
  catalog : ClassificationCatalog,
) -> Array[ProductCode] {
  let products : Array[ProductCode] = []
  for product in catalog.products {
    if !code_state_is_live(product.state) {
      products.push(product)
    }
  }
  products
}

///|
pub fn catalog_levels(catalog : ClassificationCatalog) -> Array[Int] {
  let levels : Array[Int] = []
  for product in catalog.products {
    if !levels.contains(product.level) {
      levels.push(product.level)
    }
  }
  let mut i = 0
  while i < levels.length() {
    let mut j = i + 1
    while j < levels.length() {
      if levels[j] < levels[i] {
        let temporary = levels[i]
        levels[i] = levels[j]
        levels[j] = temporary
      }
      j += 1
    }
    i += 1
  }
  levels
}

///|
pub fn catalog_count_by_state(
  catalog : ClassificationCatalog,
  state : CodeState,
) -> Int {
  let mut count = 0
  for product in catalog.products {
    if product.state == state {
      count += 1
    }
  }
  count
}

///|
pub fn catalog_count_by_level(
  catalog : ClassificationCatalog,
  level : Int,
) -> Int {
  let mut count = 0
  for product in catalog.products {
    if product.level == level {
      count += 1
    }
  }
  count
}

///|
pub fn catalog_validate(catalog : ClassificationCatalog) -> Array[String] {
  let errors : Array[String] = []
  for system in catalog.systems {
    if system.id.trim() == "" {
      errors.push("system id is empty")
    }
    if system.name.trim() == "" {
      errors.push("system name is empty")
    }
  }
  for version in catalog.versions {
    if version.label.trim() == "" {
      errors.push("version label is empty")
    }
    if version.year < 0 {
      errors.push("version year is negative")
    }
    if catalog_find_system(catalog, version.system.id) is None {
      errors.push("version references unknown system")
    }
  }
  for product in catalog.products {
    if product.code.trim() == "" {
      errors.push("product code is empty")
    }
    if product.level < 0 {
      errors.push("product level is negative")
    }
    if catalog_find_version(
        catalog,
        product.version.system.id,
        product.version.label,
      )
      is None {
      errors.push("product references unknown version")
    }
    match product.parent {
      Some(parent) =>
        if parent == product.code {
          errors.push("product cannot parent itself")
        }
      None => ()
    }
  }
  errors
}

///|
pub fn catalog_is_valid(catalog : ClassificationCatalog) -> Bool {
  catalog_validate(catalog).is_empty()
}

///|
pub fn catalog_merge(
  left : ClassificationCatalog,
  right : ClassificationCatalog,
) -> ClassificationCatalog {
  let mut result = empty_catalog()
  for system in left.systems {
    result = catalog_add_system(result, system)
  }
  for system in right.systems {
    result = catalog_add_system(result, system)
  }
  for version in left.versions {
    result = catalog_add_version(result, version)
  }
  for version in right.versions {
    result = catalog_add_version(result, version)
  }
  result = catalog_add_products(result, left.products)
  catalog_add_products(result, right.products)
}

///|
pub fn catalog_system_ids(catalog : ClassificationCatalog) -> Array[String] {
  let ids : Array[String] = []
  for system in catalog.systems {
    if !ids.contains(system.id) {
      ids.push(system.id)
    }
  }
  sort_codes_lexical(ids)
}

///|
pub fn catalog_version_labels(
  catalog : ClassificationCatalog,
  system_id : String,
) -> Array[String] {
  let labels : Array[String] = []
  for version in catalog.versions {
    if version.system.id == system_id && !labels.contains(version.label) {
      labels.push(version.label)
    }
  }
  sort_codes_lexical(labels)
}

///|
pub fn catalog_snapshot(catalog : ClassificationCatalog) -> String {
  "systems=" +
  catalog.systems.length().to_string() +
  ",versions=" +
  catalog.versions.length().to_string() +
  ",products=" +
  catalog.products.length().to_string()
}
