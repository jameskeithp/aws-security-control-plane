output "recorder_name" {
  description = "Name of the AWS Config configuration recorder."
  value       = aws_config_configuration_recorder.main.name
}

output "delivery_channel_name" {
  description = "Name of the AWS Config delivery channel."
  value       = aws_config_delivery_channel.main.name
}
