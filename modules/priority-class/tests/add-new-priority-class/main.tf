module "test" {
  source = "../../"

  priority_class = [
    {
      name  = "important"
      value = "2000000"
    },
  ]
}

output "priority_class" {
  value = module.test.priority_class
}
