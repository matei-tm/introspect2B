# Security services: Inspector v2 and Security Hub
resource "aws_inspector2_enabler" "account" {
  account_ids    = ["self"]
  resource_types = ["ECR", "EC2", "LAMBDA"]
}

resource "aws_securityhub_account" "this" {
  enable_default_standards = false
}

resource "aws_securityhub_standards_subscription" "cis" {
  depends_on   = [aws_securityhub_account.this]
  standards_arn = "arn:aws:securityhub:${var.aws_region}::standards/cis-aws-foundations-benchmark/v/1.4.0"
}
