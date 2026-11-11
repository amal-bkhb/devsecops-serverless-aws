# Règle 1 : toute ressource taguable doit porter Project, Owner et Environment (non vides).
package terraform.tags

required_tags := {"Project", "Owner", "Environment"}

# Une ressource est "taguable" si le provider expose l'attribut tags_all.
taggable(after) if "tags_all" in object.keys(after)

# tags_all peut valoir null : on le traite alors comme un objet vide.
tags_of(after) := after.tags_all if is_object(after.tags_all)
else := {}

deny contains msg if {
	some rc in input.resource_changes
	rc.mode == "managed"
	not "delete" in rc.change.actions
	after := rc.change.after
	is_object(after)
	taggable(after)
	present := {k | some k, v in tags_of(after); v != ""}
	missing := required_tags - present
	count(missing) > 0
	msg := sprintf("%s : tags obligatoires manquants %v", [rc.address, sort(missing)])
}
