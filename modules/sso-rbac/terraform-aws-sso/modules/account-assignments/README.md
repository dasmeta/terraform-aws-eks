# AWS SSO Account Assignments Module

This module assigns [AWS SSO permission sets](https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetsconcept.html) to Users and Groups from the [AWS SSO Identity Source](https://docs.aws.amazon.com/singlesignon/latest/userguide/manage-your-identity-source.html).

Some english-language examples of this would be:

- users who are in the group `Administrators` should be assigned the permission set `AdmininstratorAccess` in the `production` account.
- users who are in the group `Developers` should be assigned the permission set `DeveloperAccess` in the `production` account
- users who are in the group `Developers` should be assigned the permission set `AdministraorAccess` in the `sandbox` account

## Usage

**IMPORTANT:** The `master` branch is used in `source` just as an example. In your code, do not pin to `master` because there may be breaking changes between releases.
Instead pin to the release tag (e.g. `?ref=tags/x.y.z`) of one of our [latest releases](https://github.com/cloudposse/terraform-aws-sso/releases).

For a complete example, see [examples/complete](/examples/complete).

```hcl
module "sso_account_assignments" {
  source = "https://github.com/cloudposse/terraform-aws-sso.git//modules/account-assignments?ref=master"

  account_assignments = [
    {
        account = "111111111111",
        permission_set_arn = "arn:aws:sso:::permissionSet/ssoins-0000000000000000/ps-31d20e5987f0ce66",
        principal_type = "GROUP",
        principal_name = "Administrators"
    },
    {
        account = "111111111111",
        permission_set_arn = "arn:aws:sso:::permissionSet/ssoins-0000000000000000/ps-955c264e8f20fea3",
        principal_type = "GROUP",
        principal_name = "Developers"
    },
    {
        account = "222222222222",
        permission_set_arn = "arn:aws:sso:::permissionSet/ssoins-0000000000000000/ps-31d20e5987f0ce66",
        principal_type = "GROUP",
        principal_name = "Developers"
    },
  ]
}

```
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.26.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.26.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ssoadmin_account_assignment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssoadmin_account_assignment) | resource |
| [aws_identitystore_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/identitystore_group) | data source |
| [aws_identitystore_user.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/identitystore_user) | data source |
| [aws_ssoadmin_instances.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssoadmin_instances) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_assignments"></a> [account\_assignments](#input\_account\_assignments) | n/a | <pre>list(object({<br>    account             = string<br>    permission_set_name = string<br>    permission_set_arn  = string<br>    principal_name      = string<br>    principal_type      = string<br>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_assignments"></a> [assignments](#output\_assignments) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
