# DynamoDB Table for application state store
resource "aws_dynamodb_table" "dapr_state" {
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "key"

  attribute {
    name = "key"
    type = "S"
  }

  tags = {
    Name = var.dynamodb_table_name
  }
}
