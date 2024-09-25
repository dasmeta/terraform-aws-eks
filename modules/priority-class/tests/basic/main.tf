module "test" {
  source = "../../"
}

output "priority_class" {
  value = module.test.priority_class
}
