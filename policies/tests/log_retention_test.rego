package terraform.log_retention_test

import data.terraform.log_retention as lr

lg(after) := {"resource_changes": [{"address": "aws_cloudwatch_log_group.api", "mode": "managed",
	"type": "aws_cloudwatch_log_group", "change": {"actions": ["create"], "after": after}}]}

test_14_jours_passe if {
	count(lr.deny) == 0 with input as lg({"retention_in_days": 14})
}

test_0_jour_conservation_infinie_bloque if {
	count(lr.deny) == 1 with input as lg({"retention_in_days": 0})
}

test_retention_absente_bloque if {
	count(lr.deny) == 1 with input as lg({"name": "x"})
}

test_365_jours_bloque if {
	count(lr.deny) == 1 with input as lg({"retention_in_days": 365})
}
