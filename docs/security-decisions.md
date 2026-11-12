
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

## Post-mortem — fusion d'une PR volontairement vulnérable (PR #3, 11/11/2026)

**Résumé.** Une PR de démonstration contenant un défaut par outil (secret factice, code dangereux,
dépendance vulnérable, test en échec, IAM `Action: "*"`, bucket non chiffré) a été fusionnée dans `main`
malgré l'échec des scans.

**Cause racine.** Le ruleset de `main` était actif, mais les deux checks (`Scans de sécurité`,
`Plan Terraform + politiques OPA`) n'étaient pas déclarés comme **obligatoires**. La fusion n'exigeait
donc qu'une PR, pas des contrôles verts.

**Ce qui a limité l'impact (défense en profondeur).** Le `deploy` a échoué : le rôle `apply` n'a ni
`iam:CreatePolicy` ni `s3:CreateBucket`. La politique `Action: "*"` et le bucket non chiffré n'ont
jamais été créés (vérifié avec `aws iam list-policies` et `aws s3api list-buckets`). Seul le code des
Lambda a été mis à jour avec le paquet de démo (fichiers non reliés à l'API, clé factice).

**Correction.** Revert par PR (#4, sans réécriture de l'historique), redéploiement propre (deploy #14,
smoke test 200/403), ajout des deux checks obligatoires au ruleset.

**Découverte.** Gitleaks ne détecte pas la clé AWS factice utilisée (aucune fuite trouvée sur les
23 commits, y compris celui qui la contient). La démonstration Gitleaks sera refaite avec un secret
factice qu'il reconnaît.

**Leçons.**
1. Un contrôle non testé ne compte pas : la protection de branche a été vérifiée par un push direct,
   mais pas par une fusion de PR rouge.
2. Le moindre privilège du rôle de déploiement est une seconde ligne de défense réelle, pas théorique.
3. Les branches de démonstration vulnérables ne doivent jamais être fusionnées ; leur PR doit rester ouverte puis être fermée.

## Phase 3 — preuves et ajustements

- **Démo v2 (PR #6)** : clé privée factice, `eval`/`shell=True`, `Jinja2==2.10`, test en échec,
  IAM `Action: "*"` et bucket non chiffré → Gitleaks, Semgrep, Trivy, pytest et Checkov échouent
  dans le même run (`if: !cancelled()`). Le job Plan est ignoré : aucun accès AWS pour du code non vérifié.
- **Démo OPA (PR #7)** : log group créé hors des modules (donc hors des validations de variables),
  rétention 60 jours → les 5 outils génériques passent, Conftest bloque (règle n° 5).
- **Ruleset vérifié** : checks « Required », fusion désactivée tant qu'ils ne sont pas verts.
- **Gitleaks limité à `HEAD`** : avec `fetch-depth: 0`, le scan portait sur toutes les branches
  récupérées ; une branche de démo bloquait des PR sans rapport. Le scan couvre désormais tout
  l'historique de `main` et les commits de la PR.
- **Clé AWS factice non détectée** par Gitleaks (identifiant inventé) : remplacée par une clé privée factice.
