# AWS Config for Inspector prerequisites
resource "aws_iam_service_linked_role" "config" {
  aws_service_name = "config.amazonaws.com"
}

data "aws_s3_bucket" "config" {
  bucket = local.config_bucket_name
}

data "aws_iam_policy_document" "config_bucket" {
  statement {
    sid     = "AWSConfigBucketPermissionsCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    resources = [data.aws_s3_bucket.config.arn]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }

  statement {
    sid     = "AWSConfigBucketDelivery"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = ["${data.aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket_policy" "config" {
  bucket = data.aws_s3_bucket.config.id
  policy = data.aws_iam_policy_document.config_bucket.json
}

resource "aws_config_configuration_recorder" "this" {
  name     = "default"
  role_arn = aws_iam_service_linked_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "default"
  s3_bucket_name = data.aws_s3_bucket.config.id

  depends_on = [aws_s3_bucket_policy.config]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}
