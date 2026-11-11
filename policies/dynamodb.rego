# Règle 4 : toute table DynamoDB doit être chiffrée avec une CMK et avoir le PITR activé.
package terraform.dynamodb

tables contains rc if {
	some rc in input.resource_changes
	rc.mode == "managed"
	rc.type == "aws_dynamodb_table"
	not "delete" in rc.change.actions
}

sse_enabled(after) if {
	some b in after.server_side_encryption
	b.enabled == true
}

# CMK dont l'ARN est connu (et qui n'est pas une clé gérée par AWS).
cmk_known(after) if {
	some b in after.server_side_encryption
	arn := b.kms_key_arn
	is_string(arn)
	arn != ""
	not contains(arn, "alias/aws/")
}

# CMK créée dans le même plan : ARN inconnu, mais kms_key_arn est déclaré dans le code.
cmk_pending(rc) if {
	some u in rc.change.after_unknown.server_side_encryption
	u.kms_key_arn == true
	config_declares_cmk(rc)
}

config_declares_cmk(rc) if {
	walk(input.configuration, [_, node])
	is_object(node)
	node.type == rc.type
	node.name == rc.name
	some b in node.expressions.server_side_encryption
	count(object.keys(b.kms_key_arn)) > 0
}

pitr_enabled(after) if {
	some b in after.point_in_time_recovery
	b.enabled == true
}

deny contains msg if {
	some rc in tables
	not sse_enabled(rc.change.after)
	msg := sprintf("%s : chiffrement côté serveur non activé", [rc.address])
}

deny contains msg if {
	some rc in tables
	sse_enabled(rc.change.after)
	not cmk_known(rc.change.after)
	not cmk_pending(rc)
	msg := sprintf("%s : chiffrement avec une clé gérée par AWS, une CMK est exigée", [rc.address])
}

deny contains msg if {
	some rc in tables
	not pitr_enabled(rc.change.after)
	msg := sprintf("%s : point-in-time recovery non activé", [rc.address])
}
