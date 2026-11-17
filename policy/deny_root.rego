package main

import rego.v1

# Conteneurs de tous les Deployments du fichier analysé
containers contains container if {
	input.kind == "Deployment"
	some container in input.spec.template.spec.containers
}

# Règle 1 : pas de conteneur lancé explicitement en root
deny contains msg if {
	some container in containers
	container.securityContext.runAsUser == 0
	msg := sprintf("Le conteneur '%v' s'exécute en root (runAsUser: 0).", [container.name])
}

# Règle 2 : runAsNonRoot doit être explicitement à true
deny contains msg if {
	some container in containers
	not container.securityContext.runAsNonRoot
	msg := sprintf("Le conteneur '%v' n'a pas 'runAsNonRoot: true'.", [container.name])
}

# Règle 3 : l'élévation de privilèges doit être interdite
deny contains msg if {
	some container in containers
	not container.securityContext.allowPrivilegeEscalation == false
	msg := sprintf("Le conteneur '%v' n'a pas 'allowPrivilegeEscalation: false'.", [container.name])
}

# Règle 4 : système de fichiers racine en lecture seule
deny contains msg if {
	some container in containers
	not container.securityContext.readOnlyRootFilesystem
	msg := sprintf("Le conteneur '%v' n'a pas 'readOnlyRootFilesystem: true'.", [container.name])
}

# Règle 5 : toutes les capacités Linux retirées
deny contains msg if {
	some container in containers
	not "ALL" in object.get(container, ["securityContext", "capabilities", "drop"], [])
	msg := sprintf("Le conteneur '%v' ne retire pas toutes les capacités (capabilities.drop: [ALL]).", [container.name])
}

# Règle 6 : une image doit avoir une version précise (pas de tag absent ni ':latest')
deny contains msg if {
	some container in containers
	not regex.match(`:[^/]+$`, container.image)
	msg := sprintf("L'image du conteneur '%v' n'a pas de tag : version imprévisible.", [container.name])
}

deny contains msg if {
	some container in containers
	endswith(container.image, ":latest")
	msg := sprintf("L'image du conteneur '%v' utilise ':latest' : version imprévisible.", [container.name])
}

# Règle 7 : limites mémoire et CPU obligatoires
deny contains msg if {
	some container in containers
	some resource in ["cpu", "memory"]
	not container.resources.limits[resource]
	msg := sprintf("Le conteneur '%v' n'a pas de limite '%v'.", [container.name, resource])
}
