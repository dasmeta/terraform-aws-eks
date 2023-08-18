module "node-problem-detector" {
  source = "./modules/node-problem-detector"

  count = var.enable_node_problem_detector ? 1 : 0
}
