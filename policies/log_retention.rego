# Règle 5 (bonus) : tout log group CloudWatch doit avoir une rétention définie, entre 1 et 30 jours.
package terraform.log_retention

max_days := 30

deny contains msg if {
	some rc in input.resource_changes
	rc.mode == "managed"
	rc.type == "aws_cloudwatch_log_group"
	not "delete" in rc.change.actions
	days := object.get(rc.change.after, "retention_in_days", 0)
	not valid(days)
	msg := sprintf("%s : rétention %v jours invalide (doit être entre 1 et %d)", [rc.address, days, max_days])
}

valid(days) if {
	is_number(days)
	days >= 1
	days <= max_days
}
