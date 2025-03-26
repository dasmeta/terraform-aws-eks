module "priority_class" {
  source = "./modules/priority-class/"

  additional_priority_classes = var.additional_priority_classes

  depends_on = [module.eks-core-components]
}
