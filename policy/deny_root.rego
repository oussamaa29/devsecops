package main

# Règle 1 : Refuser tout conteneur avec runAsUser = 0 (root explicite)
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.runAsUser == 0
  msg := sprintf(
    "VIOLATION: Le conteneur '%v' s'exécute en tant que root (runAsUser: 0). Utilisez un utilisateur non-root.",
    [container.name]
  )
}

# Règle 2 : Refuser si runAsNonRoot n'est pas explicitement défini à true
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.runAsNonRoot
  msg := sprintf(
    "VIOLATION: Le conteneur '%v' n'a pas 'runAsNonRoot: true'. Définissez cette propriété dans securityContext.",
    [container.name]
  )
}

# Règle 3 : Refuser si allowPrivilegeEscalation n'est pas false
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.allowPrivilegeEscalation == false
  msg := sprintf(
    "VIOLATION: Le conteneur '%v' n'a pas 'allowPrivilegeEscalation: false'.",
    [container.name]
  )
}
