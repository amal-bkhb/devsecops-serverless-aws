package terraform.dynamodb_test

import data.terraform.dynamodb as ddb

cmk := "arn:aws:kms:eu-west-3:111111111111:key/abcd-1234"

plan(after, after_unknown, config_sse) := {
	"resource_changes": [{
		"address": "module.dynamodb.aws_dynamodb_table.this",
		"mode": "managed", "type": "aws_dynamodb_table", "name": "this",
		"change": {"actions": ["create"], "after": after, "after_unknown": after_unknown},
	}],
	"configuration": {"root_module": {"module_calls": {"dynamodb": {"module": {"resources": [{
		"address": "aws_dynamodb_table.this", "type": "aws_dynamodb_table", "name": "this",
		"expressions": {"server_side_encryption": [config_sse]},
	}]}}}}},
}

conforme := {"server_side_encryption": [{"enabled": true, "kms_key_arn": cmk}],
	"point_in_time_recovery": [{"enabled": true}]}

config_cmk := {"enabled": {"constant_value": true}, "kms_key_arn": {"references": ["aws_kms_key.this.arn"]}}

config_sans_cmk := {"enabled": {"constant_value": true}}

test_cmk_connue_et_pitr_passe if {
	count(ddb.deny) == 0 with input as plan(conforme, {}, config_cmk)
}

test_cmk_creee_dans_le_meme_plan_passe if {
	after := {"server_side_encryption": [{"enabled": true}], "point_in_time_recovery": [{"enabled": true}]}
	unknown := {"server_side_encryption": [{"kms_key_arn": true}]}
	count(ddb.deny) == 0 with input as plan(after, unknown, config_cmk)
}

test_cle_geree_par_aws_bloque if {
	after := {"server_side_encryption": [{"enabled": true}], "point_in_time_recovery": [{"enabled": true}]}
	unknown := {"server_side_encryption": [{"kms_key_arn": true}]}
	count(ddb.deny) == 1 with input as plan(after, unknown, config_sans_cmk)
}

test_alias_aws_dynamodb_bloque if {
	after := {"server_side_encryption": [{"enabled": true, "kms_key_arn": "arn:aws:kms:eu-west-3:111111111111:alias/aws/dynamodb"}],
		"point_in_time_recovery": [{"enabled": true}]}
	count(ddb.deny) == 1 with input as plan(after, {}, config_sans_cmk)
}

test_chiffrement_absent_bloque if {
	after := {"server_side_encryption": [], "point_in_time_recovery": [{"enabled": true}]}
	count(ddb.deny) == 1 with input as plan(after, {}, config_sans_cmk)
}

test_pitr_desactive_bloque if {
	after := object.union(conforme, {"point_in_time_recovery": [{"enabled": false}]})
	count(ddb.deny) == 1 with input as plan(after, {}, config_cmk)
}

test_pitr_absent_bloque if {
	after := object.remove(conforme, ["point_in_time_recovery"])
	count(ddb.deny) == 1 with input as plan(after, {}, config_cmk)
}
