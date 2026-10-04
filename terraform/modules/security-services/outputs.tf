output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector."
  value       = aws_guardduty_detector.main.id
}

output "securityhub_account_id" {
  description = "Account ID enrolled in Security Hub."
  value       = aws_securityhub_account.main.id
}
