output "table_name" {
  description = "Table name — injected into the app as APP_DYNAMODB_TABLE"
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "Table ARN — consumed by the API pod's IRSA policy (Issue #10)"
  value       = aws_dynamodb_table.this.arn
}
