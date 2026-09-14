output "registry_id" {
  description = "Yandex Container Registry ID"
  value       = yandex_container_registry.exam_registry.id
}

output "repository_name" {
  description = "Container repository name"
  value       = yandex_container_repository.app_repository.name
}

output "kubernetes_cluster_name" {
  description = "Kubernetes cluster name"
  value       = yandex_kubernetes_cluster.exam_cluster.name
}

output "kubernetes_cluster_id" {
  description = "Kubernetes cluster ID"
  value       = yandex_kubernetes_cluster.exam_cluster.id
}

output "postgres_fqdn" {
  description = "PostgreSQL host FQDN"
  value       = yandex_mdb_postgresql_cluster.exam_postgres.host[0].fqdn
}