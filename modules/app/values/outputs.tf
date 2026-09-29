output "documents" {
  description = "The release's values documents, in the order Helm merges them."
  value       = [yamlencode(local.values), local.identity_values]
}
