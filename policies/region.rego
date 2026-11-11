# Règle 2 : seule la région eu-west-3 (Paris) est autorisée.
package terraform.region

allowed := "eu-west-3"

aws_providers contains p if {
	some _, p in input.configuration.provider_config
	p.name == "aws"
}

# Région du provider : valeur écrite en dur...
provider_region(p) := r if {
	r := p.expressions.region.constant_value
	is_string(r)
}

# ... ou référence à une variable (region = var.region), résolue depuis input.variables.
provider_region(p) := r if {
	some ref in p.expressions.region.references
	startswith(ref, "var.")
	r := input.variables[substring(ref, 4, -1)].value
}

# A. Provider sans région déclarée : on refuse (la région dépendrait de l'environnement d'exécution).
deny contains msg if {
	some p in aws_providers
	not p.expressions.region
	msg := sprintf("provider %s : région non déclarée (doit être %s)", [p.full_name, allowed])
}

# B. Provider configuré sur une autre région.
deny contains msg if {
	some p in aws_providers
	r := provider_region(p)
	r != allowed
	msg := sprintf("provider %s : région %s interdite (seule %s est autorisée)", [p.full_name, r, allowed])
}

# C. Ressource qui force sa propre région (provider AWS >= 6).
deny contains msg if {
	some rc in input.resource_changes
	rc.mode == "managed"
	not "delete" in rc.change.actions
	is_object(rc.change.after)
	r := rc.change.after.region
	is_string(r)
	r != allowed
	msg := sprintf("%s : région %s interdite (seule %s est autorisée)", [rc.address, r, allowed])
}
