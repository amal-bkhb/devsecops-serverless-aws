
## Exceptions Checkov — module api

| Règle | Ressource | Justification |
|---|---|---|
| CKV_AWS_158 (log group chiffré par KMS) | aws_cloudwatch_log_group.access | Journaux d'accès sans donnée sensible ; chiffrement par défaut de CloudWatch suffisant ; évite une 2e CMK (~1 $/mois). |
| CKV_AWS_338 (rétention ≥ 1 an) | aws_cloudwatch_log_group.access | Rétention volontairement ≤ 30 jours (règle OPA n° 5) pour rester dans le Free Tier. |
