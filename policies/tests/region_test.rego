package terraform.region_test

import data.terraform.region

provider_var := {"aws": {"name": "aws", "full_name": "registry.terraform.io/hashicorp/aws",
	"expressions": {"region": {"references": ["var.region"]}}}}

plan(provider_config, var_region, resources) := {
	"configuration": {"provider_config": provider_config},
	"variables": {"region": {"value": var_region}},
	"resource_changes": resources,
}

table(after) := [{"address": "aws_dynamodb_table.tasks", "mode": "managed",
	"type": "aws_dynamodb_table", "change": {"actions": ["create"], "after": after}}]

test_paris_passe if {
	count(region.deny) == 0 with input as plan(provider_var, "eu-west-3", table({"name": "t"}))
}

test_provider_autre_region_bloque if {
	count(region.deny) == 1 with input as plan(provider_var, "us-east-1", table({"name": "t"}))
}

test_provider_region_en_dur_bloque if {
	cfg := {"aws": {"name": "aws", "full_name": "aws", "expressions": {"region": {"constant_value": "eu-west-1"}}}}
	count(region.deny) == 1 with input as plan(cfg, "eu-west-3", [])
}

test_provider_sans_region_bloque if {
	cfg := {"aws": {"name": "aws", "full_name": "aws", "expressions": {}}}
	count(region.deny) == 1 with input as plan(cfg, "eu-west-3", [])
}

test_ressource_force_autre_region_bloque if {
	count(region.deny) == 1 with input as plan(provider_var, "eu-west-3", table({"name": "t", "region": "us-east-1"}))
}

test_ressource_globale_sans_region_passe if {
	iam := [{"address": "aws_iam_role.r", "mode": "managed", "type": "aws_iam_role",
		"change": {"actions": ["create"], "after": {"name": "r"}}}]
	count(region.deny) == 0 with input as plan(provider_var, "eu-west-3", iam)
}
