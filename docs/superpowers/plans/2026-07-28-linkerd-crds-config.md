# Linkerd CRD Chart Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow EKS module consumers to pass explicit Helm values to the
Linkerd CRD chart without changing existing defaults.

**Architecture:** Extend the existing grouped `linkerd` interface with an
optional `configs_crds` map. Forward the map through the root module into the
Linkerd child module, where it is JSON-encoded only for the `linkerd-crds` Helm
release.

**Tech Stack:** Terraform >= 1.3, HashiCorp Helm provider, Terraform native tests

---

### Task 1: Add the failing CRD values contract test

**Files:**
- Create: `modules/linkerd/tests/configs_crds.tftest.hcl`

- [ ] **Step 1: Write the failing test**

```hcl
mock_provider "helm" {}
mock_provider "tls" {}

run "forwards_crd_chart_values" {
  command = plan

  variables {
    configs_crds = {
      installGatewayAPI = true
    }
  }

  assert {
    condition = jsondecode(
      helm_release.this_crds[0].values[0]
    ).installGatewayAPI == true
    error_message = "The linkerd-crds release must receive configs_crds values."
  }
}
```

- [ ] **Step 2: Initialize the child module**

Run:

```bash
terraform -chdir=modules/linkerd init -backend=false
```

Expected: provider and module initialization completes successfully.

- [ ] **Step 3: Run the test and verify RED**

Run:

```bash
terraform -chdir=modules/linkerd test -filter=tests/configs_crds.tftest.hcl
```

Expected: FAIL because input variable `configs_crds` is undeclared.

- [ ] **Step 4: Commit the failing test**

```bash
git add modules/linkerd/tests/configs_crds.tftest.hcl
git commit -m "test: define Linkerd CRD values contract"
```

### Task 2: Implement Linkerd child-module support

**Files:**
- Modify: `modules/linkerd/variables.tf`
- Modify: `modules/linkerd/main.tf`

- [ ] **Step 1: Declare the child-module input**

Add to `modules/linkerd/variables.tf`:

```hcl
variable "configs_crds" {
  type        = any
  default     = {}
  description = "Configurations to pass and override defaults for the linkerd-crds Helm chart"
}
```

- [ ] **Step 2: Pass values to the CRD release**

Add inside `helm_release.this_crds` in `modules/linkerd/main.tf`:

```hcl
values = [jsonencode(var.configs_crds)]
```

- [ ] **Step 3: Run the test and verify GREEN**

Run:

```bash
terraform -chdir=modules/linkerd test -filter=tests/configs_crds.tftest.hcl
```

Expected: PASS for `forwards_crd_chart_values`.

- [ ] **Step 4: Commit the child-module behavior**

```bash
git add modules/linkerd/variables.tf modules/linkerd/main.tf
git commit -m "feat: support Linkerd CRD chart values"
```

### Task 3: Expose the root EKS interface

**Files:**
- Modify: `variables.tf`
- Modify: `main.tf`

- [ ] **Step 1: Add the optional grouped attribute**

In the root `variable "linkerd"` object, add:

```hcl
configs_crds = optional(any, {}) # allows overrides for the linkerd-crds chart
```

- [ ] **Step 2: Forward the value**

In the root `module "linkerd"` block, add:

```hcl
configs_crds = var.linkerd.configs_crds
```

- [ ] **Step 3: Format and validate the interface**

Run:

```bash
terraform fmt variables.tf main.tf
terraform validate
```

Expected: formatting makes no further changes and validation succeeds.

- [ ] **Step 4: Commit the root interface**

```bash
git add variables.tf main.tf
git commit -m "feat: expose Linkerd CRD chart configuration"
```

### Task 4: Document the consumer configuration

**Files:**
- Modify: `examples/eks-with-linkerd/1-example.tf`
- Modify: `modules/linkerd/README.md`

- [ ] **Step 1: Update the Linkerd example**

Change the example's `linkerd` block to:

```hcl
linkerd = {
  enabled = true
  configs_crds = {
    installGatewayAPI = true
  }
}
```

- [ ] **Step 2: Regenerate module documentation**

Run:

```bash
pre-commit run terraform_docs --files modules/linkerd/variables.tf modules/linkerd/README.md
```

Expected: the generated Inputs table contains `configs_crds` with default `{}`.

- [ ] **Step 3: Commit documentation**

```bash
git add examples/eks-with-linkerd/1-example.tf modules/linkerd/README.md
git commit -m "docs: show Linkerd Gateway API CRD configuration"
```

### Task 5: Complete repository verification

**Files:**
- Verify all files changed by Tasks 1-4

- [ ] **Step 1: Run the targeted test**

```bash
terraform -chdir=modules/linkerd test -filter=tests/configs_crds.tftest.hcl
```

Expected: PASS.

- [ ] **Step 2: Run formatting checks**

```bash
terraform fmt -check -recursive
```

Expected: exit code 0 with no file output.

- [ ] **Step 3: Validate the child example**

```bash
terraform -chdir=modules/linkerd/examples/basic init -backend=false
terraform -chdir=modules/linkerd/examples/basic validate
```

Expected: initialization completes and validation reports success.

- [ ] **Step 4: Run changed-file hooks**

```bash
pre-commit run --files \
  variables.tf \
  main.tf \
  modules/linkerd/variables.tf \
  modules/linkerd/main.tf \
  modules/linkerd/tests/configs_crds.tftest.hcl \
  modules/linkerd/README.md \
  examples/eks-with-linkerd/1-example.tf
```

Expected: all hooks pass.

- [ ] **Step 5: Review the final diff**

```bash
git diff main...HEAD --check
git diff main...HEAD --stat
git status --short
```

Expected: no whitespace errors; only the approved Linkerd interface,
documentation, tests, and planning artifacts are changed; worktree is clean
after commits.
