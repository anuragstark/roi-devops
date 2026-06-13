output "alarm_arns" {
  description = "ARNs of all CloudWatch alarms"
  value = [
    aws_cloudwatch_metric_alarm.ec2_cpu_high.arn,
    aws_cloudwatch_metric_alarm.rds_connections_high.arn,
    aws_cloudwatch_metric_alarm.rds_storage_low.arn,
    aws_cloudwatch_metric_alarm.rds_cpu_high.arn,
  ]
}
