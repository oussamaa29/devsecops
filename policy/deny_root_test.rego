package main

import rego.v1

# Lancés par `conftest verify --policy policy/`

secure_container := {
	"name": "app",
	"image": "flask-api:1.0.0",
	"securityContext": {
		"runAsNonRoot": true,
		"runAsUser": 10001,
		"allowPrivilegeEscalation": false,
		"readOnlyRootFilesystem": true,
		"capabilities": {"drop": ["ALL"]},
	},
	"resources": {"limits": {"cpu": "500m", "memory": "128Mi"}},
}

deployment_with(container) := {
	"kind": "Deployment",
	"spec": {"template": {"spec": {"containers": [container]}}},
}

with_security_context(patch) := object.union(
	secure_container,
	{"securityContext": object.union(secure_container.securityContext, patch)},
)

test_secure_deployment_is_allowed if {
	doc := deployment_with(secure_container)
	count(deny) == 0 with input as doc
}

test_root_user_is_denied if {
	doc := deployment_with(with_security_context({"runAsUser": 0}))
	"Le conteneur 'app' s'exécute en root (runAsUser: 0)." in deny with input as doc
}

test_missing_run_as_non_root_is_denied if {
	doc := deployment_with(with_security_context({"runAsNonRoot": false}))
	"Le conteneur 'app' n'a pas 'runAsNonRoot: true'." in deny with input as doc
}

test_privilege_escalation_is_denied if {
	doc := deployment_with(with_security_context({"allowPrivilegeEscalation": true}))
	"Le conteneur 'app' n'a pas 'allowPrivilegeEscalation: false'." in deny with input as doc
}

test_writable_root_filesystem_is_denied if {
	doc := deployment_with(with_security_context({"readOnlyRootFilesystem": false}))
	count(deny) == 1 with input as doc
}

test_capabilities_not_dropped_is_denied if {
	doc := deployment_with(with_security_context({"capabilities": {"drop": ["NET_RAW"]}}))
	count(deny) == 1 with input as doc
}

test_latest_tag_is_denied if {
	doc := deployment_with(object.union(secure_container, {"image": "flask-api:latest"}))
	"L'image du conteneur 'app' utilise ':latest' : version imprévisible." in deny with input as doc
}

test_missing_tag_is_denied if {
	doc := deployment_with(object.union(secure_container, {"image": "registry.local:5000/flask-api"}))
	"L'image du conteneur 'app' n'a pas de tag : version imprévisible." in deny with input as doc
}

test_missing_memory_limit_is_denied if {
	doc := deployment_with(json.remove(secure_container, ["resources/limits/memory"]))
	"Le conteneur 'app' n'a pas de limite 'memory'." in deny with input as doc
}

test_other_kinds_are_ignored if {
	count(deny) == 0 with input as {"kind": "Service"}
}
