# IAM Policy for enabling security services (Inspector, Security Hub)
data "aws_iam_policy_document" "security_services_access" {
  statement {
    effect = "Allow"
    actions = [
      "inspector2:*",
      "securityhub:*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "security_services_access" {
  name        = "SecurityServicesAccess"
  description = "Permissions to administer Amazon Inspector and AWS Security Hub"
  policy      = data.aws_iam_policy_document.security_services_access.json

  tags = {
    Name = "SecurityServicesAccess"
  }
}

locals {
  caller_arn_parts = split("/", data.aws_caller_identity.current.arn)
  caller_user_name = element(local.caller_arn_parts, length(local.caller_arn_parts) - 1)
}

resource "aws_iam_user_policy_attachment" "security_services_access" {
  count = var.attach_security_services_policy_to_current_user ? 1 : 0

  user       = local.caller_user_name
  policy_arn = aws_iam_policy.security_services_access.arn
}
