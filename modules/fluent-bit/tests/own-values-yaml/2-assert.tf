resource "test_assertions" "api_url" {
  component = "supply_own_yaml_file"

  equal "scheme" {
    description = "As module does not have any output and data just make sure the case runs. Probably can be thrown away."
    got         = "all good"
    want        = "all good"
  }
}
