output "url" {
  description = "Open this once the certificate is issued."
  value       = module.app.url
}

output "admin_sign_in" {
  description = "Sign in as akadmin. Copy the password without printing it: az keyvault secret show --vault-name <vault> --name <secret> --query value -o tsv | pbcopy"
  value       = module.app.admin_sign_in
}

output "name_servers" {
  description = "Delegate dns.zone_name to these from its parent zone."
  value       = module.platform.name_servers
}

output "resource_group_name" {
  description = "Everything Azure-side is in this resource group (plus the AKS node group)."
  value       = module.platform.resource_group_name
}

output "cluster_name" {
  description = "The AKS cluster, for kubectl: az aks get-credentials --resource-group <resource_group_name> --name <cluster_name>, then kubelogin convert-kubeconfig -l azurecli."
  value       = module.platform.cluster.name
}
