output "state_bucket" {
  value = aws_s3_bucket.state.id
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "role_apply_arn" {
  value = aws_iam_role.apply.arn
}

output "role_plan_arn" {
  value = aws_iam_role.plan.arn
}
