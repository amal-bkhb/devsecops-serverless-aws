# DEMO VOLONTAIREMENT NON CONFORME - ne jamais fusionner
# Log group ajouté directement, hors des modules : la validation des variables ne s'applique pas.
resource "aws_cloudwatch_log_group" "demo_hors_module" {
  #checkov:skip=CKV_AWS_158:Meme exception que le module api (journaux sans donnee sensible)
  #checkov:skip=CKV_AWS_338:Meme exception que le module api (retention courte pour le cout)
  name              = "/demo/hors-module"
  retention_in_days = 60
}
