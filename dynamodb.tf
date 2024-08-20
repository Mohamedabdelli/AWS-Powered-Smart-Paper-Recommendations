
resource "aws_dynamodb_table" "dynamodb-table-experts" {
  name           = var.table_name
  hash_key       = "id"
  billing_mode="PAY_PER_REQUEST"

  attribute {
    name = "id"
    type = "S"
  }
  tags = {
    Name        = "dynamodb-table-experts"
    Environment = "production"
  }
}

output "name-table" {
  value = aws_dynamodb_table.dynamodb-table-experts.name
}