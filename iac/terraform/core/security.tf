# Security services: Inspector v2 and Security Hub
resource "aws_inspector2_enabler" "account" {
  count         = var.attach_security_services_policy_to_current_user ? 1 : 0
  account_ids   = [data.aws_caller_identity.current.account_id]
  resource_types = ["ECR", "EC2", "LAMBDA"]
}

resource "aws_securityhub_account" "this" {
  count                  = var.attach_security_services_policy_to_current_user ? 1 : 0
  enable_default_standards = false
}

resource "aws_securityhub_standards_subscription" "cis" {
  count        = var.attach_security_services_policy_to_current_user ? 1 : 0
  depends_on   = [aws_securityhub_account.this]
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/cis-aws-foundations-benchmark/v/1.4.0"
}
