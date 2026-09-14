variable "zone" {
  description = "Yandex Cloud availability zone"
  type        = string
  default     = "ru-central1-a"
}

variable "db_password" {
  description = "Password for PostgreSQL user db_user"
  type        = string
  sensitive   = true
}