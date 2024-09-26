module "test" {
  source = "../../"

  additional_priority_classes = [
    {
      name  = "important"
      value = "2000000"
    },
  ]
}
