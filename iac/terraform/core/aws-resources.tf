# DynamoDB Table for application state store
resource "aws_dynamodb_table" "claims" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "key"

  attribute {
    name = "key"
    type = "S"
  }

  tags = {
    Name = var.dynamodb_table_name
  }
}

# S3 Bucket for claim notes
resource "aws_s3_bucket" "claim_notes" {
  bucket = "claim-notes-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "claim-notes"
  }
}

# Block public access to claim notes bucket
resource "aws_s3_bucket_public_access_block" "claim_notes" {
  bucket = aws_s3_bucket.claim_notes.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for claim notes
resource "aws_s3_bucket_versioning" "claim_notes" {
  bucket = aws_s3_bucket.claim_notes.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption for claim notes
resource "aws_s3_bucket_server_side_encryption_configuration" "claim_notes" {
  bucket = aws_s3_bucket.claim_notes.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
