output "url" {
  description = "Where DataQube is served."
  value       = "https://${local.app}"
}

output "admin_sign_in" {
  description = "The bundled identity provider's bootstrap administrator: sign in as akadmin with the password in this Key Vault secret (null with your own identity provider)."
  # A lookup, not an index: with your own identity provider the secret does
  # not exist, and Terraform checks an index even in the branch not taken.
  value = var.identity.type == "bundled" ? {
    user_name                 = "akadmin"
    password_key_vault        = var.platform.key_vault.name
    password_key_vault_secret = one([for key, secret in azurerm_key_vault_secret.generated : secret.name if key == "authentik-bootstrap-password"])
  } : null
}
