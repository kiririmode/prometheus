// TFLint configuration for Prometheus monitoring infrastructure
// https://github.com/terraform-linters/tflint

config {
  // Enable module inspection (changed from "module" in v0.54.0+)
  call_module_type = "all"  // all | local | none

  // Force provider version check
  force = false

  // Disable colored output in CI
  disabled_by_default = false
}

// Terraform plugin (built-in)
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

// AWS plugin for AWS-specific best practices
// https://github.com/terraform-linters/tflint-ruleset-aws
plugin "aws" {
  enabled = true
  version = "0.36.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

// Terraform core rules
rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true

  // Variable naming: snake_case
  variable {
    format = "snake_case"
  }

  // Output naming: snake_case
  output {
    format = "snake_case"
  }

  // Locals naming: snake_case
  locals {
    format = "snake_case"
  }

  // Module naming: snake_case
  module {
    format = "snake_case"
  }
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

// AWS-specific rules (examples - adjust based on project needs)
rule "aws_resource_missing_tags" {
  enabled = false  // Disabled as we use merge() for tags
}

rule "aws_instance_invalid_type" {
  enabled = true
}

rule "aws_iam_policy_document_gov_friendly_arns" {
  enabled = false  // Not using GovCloud
}

// Note: aws_iam_role_policy_too_long_policy rule was removed in newer AWS plugin versions

rule "aws_s3_bucket_invalid_acl" {
  enabled = true
}

rule "aws_db_instance_invalid_type" {
  enabled = true
}

rule "aws_elasticache_cluster_invalid_type" {
  enabled = true
}

// Note: aws_ecs_task_definition_invalid_cpu_memory rule was removed in newer AWS plugin versions
