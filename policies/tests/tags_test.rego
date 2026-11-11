package terraform.tags_test

import data.terraform.tags

ressource(actions, after) := {"resource_changes": [{
	"address": "aws_dynamodb_table.tasks",
	"mode": "managed",
	"type": "aws_dynamodb_table",
	"change": {"actions": actions, "after": after},
}]}

tags_complets := {"Project": "devsecops-serverless", "Owner": "amal-bkhb", "Environment": "dev"}

test_tous_les_tags_passe if {
	count(tags.deny) == 0 with input as ressource(["create"], {"tags_all": tags_complets})
}

test_tag_owner_manquant_bloque if {
	count(tags.deny) == 1 with input as ressource(["create"], {"tags_all": {"Project": "p", "Environment": "dev"}})
}

test_tag_vide_bloque if {
	count(tags.deny) == 1 with input as ressource(["update"], {"tags_all": object.union(tags_complets, {"Owner": ""})})
}

test_tags_null_bloque if {
	count(tags.deny) == 1 with input as ressource(["create"], {"tags_all": null})
}

test_ressource_non_taguable_ignoree if {
	count(tags.deny) == 0 with input as ressource(["create"], {"function_name": "f"})
}

test_suppression_ignoree if {
	count(tags.deny) == 0 with input as ressource(["delete"], null)
}
