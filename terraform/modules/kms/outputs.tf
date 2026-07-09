output "key_arn" {
  description = "ARN of the CMK — referenced by encrypted resources"
  value       = aws_kms_key.this.arn
}

output "key_id" {
  description = "Key ID of the CMK"
  value       = aws_kms_key.this.key_id
}

output "alias_name" {
  description = "Key alias (alias/<project>-<env>-<purpose>)"
  value       = aws_kms_alias.this.name
}
