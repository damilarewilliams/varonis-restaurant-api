output "app_log_group_name" {
  description = "Application log group — Fluent Bit output destination"
  value       = aws_cloudwatch_log_group.app.name
}

output "app_log_group_arn" {
  description = "Application log group ARN"
  value       = aws_cloudwatch_log_group.app.arn
}

output "shipper_role_arn" {
  description = "IRSA role for the Fluent Bit ServiceAccount annotation"
  value       = aws_iam_role.shipper.arn
}

output "error_alarm_name" {
  description = "CloudWatch alarm on application ERROR spikes"
  value       = aws_cloudwatch_metric_alarm.app_errors.alarm_name
}
