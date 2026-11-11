
## Exceptions Checkov — module api

| Règle | Ressource | Justification |
|---|---|---|
| CKV_AWS_158 (log group chiffré par KMS) | aws_cloudwatch_log_group.access | Journaux d'accès sans donnée sensible ; chiffrement par défaut de CloudWatch suffisant ; évite une 2e CMK (~1 $/mois). |
| CKV_AWS_338 (rétention ≥ 1 an) | aws_cloudwatch_log_group.access | Rétention volontairement ≤ 30 jours (règle OPA n° 5) pour rester dans le Free Tier. |

## Bootstrap — bucket d'état Terraform (Phase 2)

| Règle Checkov | Décision | Justification |
|---|---|---|
| CKV_AWS_145 (KMS) | Ignorée | Chiffrement SSE-S3 (AES-256) ; accès contrôlé par IAM, blocage public et politique TLS ; une 2e CMK sortirait du budget. |
| CKV_AWS_144 (réplication) | Ignorée | Région unique eu-west-3 imposée (règle OPA n° 2) ; le versioning couvre la récupération. |
| CKV_AWS_18 (logs d'accès) | Ignorée (temporaire) | Appels de gestion tracés par CloudTrail. Point le plus faible : data events CloudTrail prévus en phase « détection ». |
| CKV2_AWS_62 (notifications) | Ignorée | Aucun consommateur prévu. |

## Rôles CI (OIDC)

- `sub` exact, sans joker : apply = `ref:refs/heads/main`, plan = `pull_request`. `aud` = `sts.amazonaws.com`.
- Préfixes séparés : le rôle apply gère `devsecops-serverless-dev-*` mais ne peut pas modifier `devsecops-serverless-ci-*` (anti-escalade), renforcé par un `Deny` explicite.
- `iam:PassRole` limité au service Lambda.
- Rôle plan : métadonnées uniquement (aucune lecture des données DynamoDB), écriture limitée au verrou `.tflock`.
- `Resource: "*"` uniquement pour `kms:CreateKey`, `kms:ListAliases` et la livraison de logs (actions sans restriction par ARN).
- Point à réduire : `kms:*` sur `key/*` (toutes les clés du compte) → réduction via CloudTrail et Access Analyzer.

## OIDC — format du claim `sub` (Phase 2)

- GitHub inclut les identifiants numériques immuables du propriétaire et du dépôt dans le `sub` :
  `repo:<owner>@<owner_id>/<repo>@<repo_id>:ref:refs/heads/main`.
- Les conditions IAM utilisent ce format exact (`StringEquals`, sans joker). Un nom de dépôt peut être
  supprimé puis recréé par un tiers (repo-jacking) ; un identifiant numérique n'est jamais réattribué.
- Diagnostic : refus `AssumeRoleWithWebIdentity` analysé en comparant la politique de confiance (AWS)
  et les claims du jeton (étape temporaire, supprimée ensuite, n'affichant jamais le jeton).
- ARN du rôle et nom du bucket stockés en secrets GitHub : ce ne sont pas des identifiants de connexion
  (inutilisables sans jeton OIDC valide pour `main`), mais ils sont masqués dans les logs publics.
- L'état du bootstrap est stocké sous `bootstrap/`, hors de `env/*` : les rôles CI n'y ont pas accès.
- Smoke test : requête signée → 200, requête non signée → 403 (API non publique).
