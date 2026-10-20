output "dynamodb_table_name" {
  value = module.dynamodb_table.table_name
}

output "dynamodb_table_arn" {
  value = module.dynamodb_table.table_arn
}

output "dynamodb_stream_arn" {
  value = module.dynamodb_table.stream_arn
}
