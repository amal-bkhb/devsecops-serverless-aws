# DEMO VOLONTAIREMENT VULNERABLE - ne jamais fusionner
resource "aws_iam_policy" "demo_admin" {
  name = "demo-admin"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "*", Resource = "*" }]
  })
}

resource "aws_s3_bucket" "demo_non_chiffre" {
  bucket = "demo-bucket-non-chiffre"
}
