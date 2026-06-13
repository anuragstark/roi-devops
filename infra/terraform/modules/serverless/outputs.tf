output "lambda_function_arn" {
  description = "ARN of the ROI cron Lambda function"
  value       = aws_lambda_function.roi_cron.arn
}

output "lambda_function_name" {
  description = "Name of the ROI cron Lambda function"
  value       = aws_lambda_function.roi_cron.function_name
}
