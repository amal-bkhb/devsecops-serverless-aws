package terraform.iam_wildcards_test

import data.terraform.iam_wildcards as iam

politique(statements) := {"resource_changes": [{
	"address": "module.iam.aws_iam_role_policy.this[\"create_task\"]",
	"mode": "managed",
	"type": "aws_iam_role_policy",
	"change": {"actions": ["create"], "after": {"policy": json.marshal({"Version": "2012-10-17", "Statement": statements})}},
}]}

table := "arn:aws:dynamodb:eu-west-3:111111111111:table/devsecops-serverless-dev-tasks"

test_politique_precise_passe if {
	count(iam.deny) == 0 with input as politique([{"Effect": "Allow", "Action": "dynamodb:PutItem", "Resource": table}])
}

test_action_etoile_bloque if {
	count(iam.deny) == 1 with input as politique([{"Effect": "Allow", "Action": "*", "Resource": table}])
}

test_etoile_dans_une_liste_bloque if {
	count(iam.deny) == 1 with input as politique([{"Effect": "Allow", "Action": ["dynamodb:PutItem", "*"], "Resource": table}])
}

test_resource_etoile_bloque if {
	count(iam.deny) == 1 with input as politique([{"Effect": "Allow", "Action": "dynamodb:PutItem", "Resource": "*"}])
}

test_notaction_dans_allow_bloque if {
	count(iam.deny) == 1 with input as politique([{"Effect": "Allow", "NotAction": "iam:*", "Resource": table}])
}

test_etoile_dans_un_deny_passe if {
	count(iam.deny) == 0 with input as politique([{"Effect": "Deny", "Action": "*", "Resource": "*"}])
}

test_statement_objet_unique_bloque if {
	inp := {"resource_changes": [{"address": "aws_iam_policy.p", "mode": "managed", "type": "aws_iam_policy",
		"change": {"actions": ["create"], "after": {"policy": json.marshal({"Statement": {"Effect": "Allow", "Action": "*", "Resource": "*"}})}}}]}
	count(iam.deny) == 2 with input as inp
}

test_politique_inconnue_avertit_sans_bloquer if {
	inp := {"resource_changes": [{"address": "aws_iam_role_policy.p", "mode": "managed", "type": "aws_iam_role_policy",
		"change": {"actions": ["create"], "after": {}, "after_unknown": {"policy": true}}}]}
	count(iam.deny) == 0 with input as inp
	count(iam.warn) == 1 with input as inp
}
