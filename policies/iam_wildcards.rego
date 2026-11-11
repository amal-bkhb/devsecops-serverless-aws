# Règle 3 : aucune action "*" ni ressource "*" dans un Allow d'une politique IAM d'identité.
package terraform.iam_wildcards

policy_types := {"aws_iam_role_policy", "aws_iam_policy", "aws_iam_user_policy", "aws_iam_group_policy"}

as_array(x) := x if is_array(x)

as_array(x) := [x] if not is_array(x)

candidates contains rc if {
	some rc in input.resource_changes
	rc.mode == "managed"
	rc.type in policy_types
	not "delete" in rc.change.actions
}

allow_statements(rc) := [st |
	raw := rc.change.after.policy
	is_string(raw)
	doc := json.unmarshal(raw)
	some st in as_array(doc.Statement)
	st.Effect == "Allow"
]

deny contains msg if {
	some rc in candidates
	some st in allow_statements(rc)
	some a in as_array(object.get(st, "Action", []))
	a == "*"
	msg := sprintf("%s : Action \"*\" interdite dans un Allow", [rc.address])
}

deny contains msg if {
	some rc in candidates
	some st in allow_statements(rc)
	some r in as_array(object.get(st, "Resource", []))
	r == "*"
	msg := sprintf("%s : Resource \"*\" interdite dans un Allow", [rc.address])
}

deny contains msg if {
	some rc in candidates
	some st in allow_statements(rc)
	some key in ["NotAction", "NotResource"]
	key in object.keys(st)
	msg := sprintf("%s : %s dans un Allow équivaut à un joker", [rc.address, key])
}

# Politique calculée après le plan (ex. ARN pas encore connu) : impossible à vérifier ici.
warn contains msg if {
	some rc in candidates
	rc.change.after_unknown.policy == true
	msg := sprintf("%s : politique inconnue au moment du plan, non vérifiée par OPA", [rc.address])
}
