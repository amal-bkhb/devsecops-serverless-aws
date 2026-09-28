# Projet : Pipeline DevSecOps pour une application serverless sécurisée sur AWS

## 1. Contexte

Je suis étudiante ingénieure en 3e année (spécialisation Cybersécurité, Cloud et Mobile Computing).
Ce projet sert à construire un profil **DevSecOps + Cloud Security** démontrable sur CV et en entretien.

**Important :** l'application n'est qu'un prétexte. La valeur du projet est dans la **chaîne de livraison sécurisée**
et dans la **preuve que les déploiements non conformes sont bloqués**.

## 2. Objectif

Concevoir un pipeline qui déploie une application serverless sur AWS :

- **sans aucun identifiant AWS stocké** dans GitHub (authentification OIDC) ;
- en **bloquant automatiquement** tout code vulnérable, tout secret exposé et toute infrastructure non conforme ;
- avec des permissions IAM en **moindre privilège** strict ;
- avec une infrastructure **100 % en code** (Terraform), auditable et reproductible.

### Objectifs mesurables (définition de « terminé » pour le projet)

1. Zéro clé d'accès AWS dans GitHub (secrets, variables ou code), et aucune clé d'accès longue durée sur mon poste.
2. Toute vulnérabilité HIGH/CRITICAL, tout secret en dur et toute violation de politique fait échouer la PR.
3. Aucune action ni ressource IAM `*` dans les politiques applicatives.
4. Aucune ressource créée manuellement dans la console AWS (hors prérequis de la section 11).
5. Au moins 4 règles OPA écrites par moi, testées et appliquées sur le plan Terraform.
6. Une PR « vulnérable » documentée montrant chaque blocage, puis la PR corrigée qui passe.

## 3. Architecture cible

```
Client → API Gateway (HTTP API, throttling)
           → Lambda (Python, une fonction par endpoint, un rôle IAM par fonction)
              → DynamoDB (table "tasks", chiffrée avec CMK KMS, PITR activé)
           → CloudWatch Logs (rétention définie)

GitHub Actions ──OIDC──► AWS IAM (rôle "plan" en lecture seule, sauf écriture sur le seul fichier .tflock, pour les PR ;
                                  rôle "apply" réservé à la branche main)

État Terraform : bucket S3 chiffré, versionné, accès public bloqué, verrouillage S3 natif (use_lockfile = true)
```

### Application

API de gestion de tâches (to-do), volontairement simple :

| Méthode | Route | Permission DynamoDB nécessaire |
|---|---|---|
| GET | /tasks | Scan |
| POST | /tasks | PutItem |
| PUT | /tasks/{id} | UpdateItem |
| DELETE | /tasks/{id} | DeleteItem |

- Python 3.12, validation des entrées avec Pydantic.
- Tests unitaires avec pytest (DynamoDB mocké avec moto).
- Paramètres sensibles dans SSM Parameter Store (SecureString), pas dans Secrets Manager (coût).
- Les Lambda lisent les SecureString **à l'exécution**. Terraform ne lit jamais leur valeur via une data source
  (sinon elle finit dans l'état, dans le plan JSON et dans le commentaire de PR).

### Contraintes

- Région : **eu-west-3 (Paris)** uniquement.
- Compte AWS au **plan gratuit** (modèle à crédits, 6 mois). Seul coût accepté : 1 clé KMS CMK ≈ 1 $/mois.
- **Ne jamais créer ni rejoindre d'AWS Organization** (y compris via IAM Identity Center) : cela fait passer le compte
  au plan payant et supprime les crédits.
- Pas d'EKS, pas de NAT Gateway, pas d'EC2.
- Tags obligatoires sur toutes les ressources : `Project`, `Owner`, `Environment`.

## 4. Outils

| Fonction | Outil |
|---|---|
| IaC | Terraform (>= 1.10) |
| CI/CD | GitHub Actions |
| Auth CI → AWS | OIDC + `aws-actions/configure-aws-credentials` |
| Auth poste local → AWS | `aws login` (identifiants temporaires, profil `devsecops-admin`) |
| Secrets dans le code | Gitleaks |
| SAST | Semgrep |
| SCA (dépendances) | Trivy (mode `fs`) |
| Scan IaC | Checkov |
| Policy-as-code | OPA + Conftest (syntaxe Rego v1) |
| Tests | pytest + moto |
| Émulation locale | LocalStack (développement uniquement) |

## 5. Structure du dépôt attendue

```
.
├── CLAUDE.md
├── README.md
├── .gitattributes         # * text=auto eol=lf
├── .gitignore             # doit exclure *.tfstate*, *.tfvars, .terraform/, .env
├── app/
│   ├── handlers/          # un fichier par endpoint
│   ├── models.py          # modèles Pydantic
│   ├── requirements.txt   # versions épinglées
│   └── tests/
├── infra/
│   ├── bootstrap/         # bucket d'état + fournisseur OIDC + rôles CI (appliqué une seule fois, en local)
│   ├── modules/
│   │   ├── api/
│   │   ├── lambda/
│   │   ├── dynamodb/
│   │   └── iam/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── backend.tf
├── policies/
│   ├── *.rego
│   └── tests/             # tests des règles OPA (opa test)
├── .github/workflows/
│   ├── pr.yml
│   └── deploy.yml
└── docs/
    ├── architecture.md
    ├── security-decisions.md
    └── screenshots/
```

`.terraform.lock.hcl` **doit être commité** (épinglage des providers).

## 6. Pipeline

### `pr.yml` (sur chaque Pull Request vers main, aucun déploiement)

Déclencheur : `pull_request` uniquement. **Jamais `pull_request_target`.**

1. Gitleaks sur l'historique complet (`actions/checkout` avec `fetch-depth: 0`).
2. Semgrep (règles Python + sécurité).
3. Trivy `fs` sur `app/` → échec si HIGH ou CRITICAL.
4. pytest.
5. Checkov sur `infra/`. Toute règle ignorée (`skip`) est justifiée dans `docs/security-decisions.md`.
6. OIDC avec le **rôle plan** → `terraform init` + `terraform plan -out` → `terraform show -json`.
7. Conftest sur le plan JSON avec `policies/`.
8. Publication du résumé du plan en commentaire de la PR (aucune valeur sensible : variables `sensitive = true`).

### `deploy.yml` (sur push dans main uniquement)

1. OIDC avec le **rôle apply**.
2. `terraform plan -out` **puis** `terraform apply` de ce plan, **dans le même job**.
   (Le plan de la PR n'existe pas dans ce workflow et serait de toute façon obsolète après la fusion.)
3. Smoke test : appel HTTP sur l'API, échec si le statut n'est pas 200.

### Protection de branche (à configurer manuellement dans GitHub)

- Fusion dans main interdite si `pr.yml` échoue.
- Pas de push direct sur main.

## 7. Règles de sécurité obligatoires

### OIDC

- Fournisseur : `token.actions.githubusercontent.com`, audience `sts.amazonaws.com`.
- Rôle **apply** : condition `sub` = `repo:amal-bkhb/devsecops-serverless-aws:ref:refs/heads/main` exactement. **Jamais de joker.**
- Rôle **plan** : condition `sub` = `repo:amal-bkhb/devsecops-serverless-aws:pull_request`.
  Permissions : lecture seule sur les ressources gérées et sur l'état, **plus** `s3:PutObject` et `s3:DeleteObject`
  limités à la clé `<chemin-état>.tflock` (exigé par le verrouillage S3 natif), plus `kms:Decrypt` si l'état est chiffré en KMS.
- Workflows : `permissions: { id-token: write, contents: read }` (+ `pull-requests: write` pour commenter).

### IAM

- Un rôle par Lambda, avec uniquement l'action DynamoDB de son endpoint, sur l'ARN exact de la table.
- Logs : uniquement sur le groupe CloudWatch de la fonction.
- Le rôle apply commence large pendant le développement, puis est **réduit** en s'appuyant sur CloudTrail
  et IAM Access Analyzer. Documenter cette réduction (avant/après) dans `docs/security-decisions.md`.

### Règles OPA à écrire (minimum)

1. Tags `Project`, `Owner`, `Environment` obligatoires sur toute ressource taguable.
2. Région autorisée : eu-west-3 uniquement.
3. Aucune action `*` ni ressource `*` dans une politique IAM.
4. DynamoDB : chiffrement avec CMK et point-in-time recovery activés.
5. (Bonus) CloudWatch Log Groups : rétention définie et ≤ 30 jours.

Chaque règle doit avoir des tests (`opa test`), avec un cas qui passe et un cas qui échoue.

## 8. Plan de travail par phases

Travailler **une phase à la fois**. Ne pas passer à la suivante tant que la définition de « terminé » n'est pas atteinte.

### Phase 0 — Prérequis (faite manuellement, voir section 11)

### Phase 1 — Application et infrastructure en local
- Code des 4 handlers + modèles + tests pytest.
- Modules Terraform (api, lambda, dynamodb, iam).
- Déploiement sur LocalStack.
- **Terminé quand :** les tests passent et l'API répond sur LocalStack.

### Phase 2 — Bootstrap AWS et OIDC
- `infra/bootstrap/` : bucket d'état, fournisseur OIDC, rôles plan et apply.
- L'état du bootstrap est local : **jamais commité**. Soit il reste hors du dépôt, soit il est migré dans le bucket après création.
- Workflow `deploy.yml` minimal (plan + apply + smoke test).
- **Terminé quand :** un push sur main déploie sur AWS sans aucune clé stockée dans GitHub.

### Phase 3 — Contrôles de sécurité sur PR
- Workflow `pr.yml` complet.
- Règles OPA + tests.
- **Terminé quand :** chaque outil peut faire échouer une PR.

### Phase 4 — Démonstration et documentation
- Branche `demo/vulnerable` avec : fausse clé AWS au format `AKIA...` (non valide), dépendance avec CVE connue,
  politique IAM avec `"Action": "*"`, bucket S3 sans chiffrement KMS ni blocage d'accès public
  (S3 chiffre déjà tous les buckets par défaut en SSE-S3 : un bucket réellement « non chiffré » n'existe plus).
- Captures de chaque échec + de la PR corrigée dans `docs/screenshots/` (ID de compte AWS flouté).
- README : objectif, schéma d'architecture (Mermaid), décisions de sécurité, résultats, instructions.
- **Terminé quand :** un recruteur peut comprendre le projet et ses preuves en 3 minutes de lecture.

### Phases ultérieures (hors périmètre pour l'instant)
- Audit de posture avec Prowler + auto-remédiation (AWS Config + Lambda).
- Détection d'attaques avec CloudTrail + GuardDuty + EventBridge, simulées avec Stratus Red Team, mappées sur MITRE ATT&CK.

## 9. Règles de travail pour Claude Code

- **Explique chaque choix de sécurité** : je dois pouvoir le justifier en entretien. Ajoute les décisions
  importantes dans `docs/security-decisions.md`.
- **N'exécute jamais `terraform apply` ou `terraform destroy` contre AWS sans ma confirmation explicite.**
  Sur LocalStack, c'est autorisé.
- **Ne crée jamais** de clés d'accès IAM, d'utilisateur IAM ou de politique `AdministratorAccess` permanente.
  (Exception existante, créée manuellement par moi : l'utilisateur humain `amal-admin`, voir section 11.)
- **Ne crée jamais** d'AWS Organization et n'active pas IAM Identity Center (plan gratuit).
- **Ne commite jamais** de fichier d'état, de `.tfvars` contenant des valeurs réelles, ni de secret.
- N'utilise pas mon ID de compte AWS en dur : passe-le en variable.
- Épingle les versions (providers Terraform, actions GitHub par SHA, dépendances Python).
- N'utilise jamais `pull_request_target` dans un workflow.
- Si une solution sort du plan gratuit, **signale le coût avant** de l'implémenter.
- Si tu n'es pas sûr qu'une option existe dans la version actuelle d'un outil, dis-le et vérifie la documentation.
- Fais des commits petits et descriptifs, une étape logique par commit.
- À la fin de chaque phase, résume ce qui a été fait, ce qui reste, et ce que je dois vérifier moi-même.

## 10. Valeurs du projet

- GitHub : `amal-bkhb/devsecops-serverless-aws`
- Profil AWS CLI local : `devsecops-admin` (région `eu-west-3`)
- `<AWS_ACCOUNT_ID>` : fourni en variable Terraform, jamais commité
- `<OWNER>` : valeur du tag Owner (à définir)

## 11. Environnement et prérequis (Phase 0, faits manuellement)

- Compte AWS au plan gratuit, MFA sur le root, root non utilisé au quotidien.
- Alerte budget AWS à 5 $.
- Accès IAM aux informations de facturation activé.
- Utilisateur IAM humain `amal-admin` (groupe `Admins` : `AdministratorAccess` + `SignInLocalDevelopmentAccess`),
  MFA activé, **aucune clé d'accès**. Accès CLI via `aws login --profile devsecops-admin` (identifiants temporaires).
  Choix fait à la place d'IAM Identity Center, qui créerait une Organization et ferait perdre le plan gratuit.
- Poste : Windows + WSL2 (Ubuntu 24.04, installé sur D:). Le projet vit dans `~/projets/`, jamais dans `/mnt/c/`.
- Docker Desktop (données sur D:), Terraform, Python 3.12, AWS CLI v2 (>= 2.32), Gitleaks, Semgrep, Trivy,
  Checkov, OPA, Conftest.
- Jeton GitHub CLI stocké en clair dans `~/.config/gh/hosts.yml` (pas de trousseau sous WSL) : risque accepté
  pour un poste personnel, à documenter dans `docs/security-decisions.md`.
