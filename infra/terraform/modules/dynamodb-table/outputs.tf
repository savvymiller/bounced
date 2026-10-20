output "table_name" {
  value = aws_dynamodb_table.main.name
}

output "table_arn" {
  value = aws_dynamodb_table.main.arn
}

output "stream_arn" {
  description = "DynamoDB Streams ARN, for the rollup consumer (PR-25) and future EventBridge pipe."
  value       = aws_dynamodb_table.main.stream_arn
}
