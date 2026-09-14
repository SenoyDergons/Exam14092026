terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }

  required_version = ">= 1.6.0"
}

provider "yandex" {
  zone = var.zone
}

# Получаем cloud/folder из текущей конфигурации Terraform/Yandex
data "yandex_client_config" "client" {}


# ============================================================
# VPC NETWORK
# ============================================================

resource "yandex_vpc_network" "exam_network" {
  name = "exam-network"
}

resource "yandex_vpc_subnet" "exam_subnet" {
  name           = "exam-public-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.exam_network.id
  v4_cidr_blocks = ["10.10.0.0/24"]
}


# ============================================================
# YANDEX CONTAINER REGISTRY
# ============================================================

resource "yandex_container_registry" "exam_registry" {
  name = "exam-registry"
}

resource "yandex_container_repository" "app_repository" {
  name = "${yandex_container_registry.exam_registry.id}/app"
}


# ============================================================
# SERVICE ACCOUNTS FOR KUBERNETES
# ============================================================

resource "yandex_iam_service_account" "k8s_service_account" {
  name = "exam-k8s-sa"
}

resource "yandex_iam_service_account" "k8s_node_account" {
  name = "exam-k8s-node-sa"
}


# Kubernetes cluster permissions

resource "yandex_resourcemanager_folder_iam_member" "k8s_agent" {
  folder_id = data.yandex_client_config.client.folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_service_account.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "vpc_public_admin" {
  folder_id = data.yandex_client_config.client.folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_service_account.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "load_balancer_admin" {
  folder_id = data.yandex_client_config.client.folder_id
  role      = "load-balancer.admin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_service_account.id}"
}

# Kubernetes nodes must be able to pull images from YCR

resource "yandex_resourcemanager_folder_iam_member" "images_puller" {
  folder_id = data.yandex_client_config.client.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_node_account.id}"
}


# ============================================================
# MANAGED KUBERNETES
# ============================================================

resource "yandex_kubernetes_cluster" "exam_cluster" {
  name       = "exam-k8s"
  network_id = yandex_vpc_network.exam_network.id

  master {
    zonal {
      zone      = var.zone
      subnet_id = yandex_vpc_subnet.exam_subnet.id
    }

    public_ip = true
  }

  service_account_id      = yandex_iam_service_account.k8s_service_account.id
  node_service_account_id = yandex_iam_service_account.k8s_node_account.id

  release_channel = "STABLE"

  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_agent,
    yandex_resourcemanager_folder_iam_member.vpc_public_admin,
    yandex_resourcemanager_folder_iam_member.load_balancer_admin,
    yandex_resourcemanager_folder_iam_member.images_puller
  ]
}


# One Kubernetes worker node

resource "yandex_kubernetes_node_group" "exam_nodes" {
  cluster_id = yandex_kubernetes_cluster.exam_cluster.id
  name       = "exam-node-group"

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      nat        = true
      subnet_ids = [yandex_vpc_subnet.exam_subnet.id]
    }

    resources {
      cores         = 2
      memory        = 2
      core_fraction = 20
    }

    boot_disk {
      type = "network-hdd"
      size = 64
    }

    scheduling_policy {
      preemptible = false
    }

    container_runtime {
      type = "containerd"
    }
  }

  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  allocation_policy {
    location {
      zone = var.zone
    }
  }
}


# ============================================================
# MANAGED POSTGRESQL
# ============================================================

resource "yandex_mdb_postgresql_cluster" "exam_postgres" {
  name        = "exam-postgresql"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.exam_network.id

  config {
    version = 15

    resources {
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-ssd"
      disk_size          = 16
    }
  }

  host {
    zone      = var.zone
    subnet_id = yandex_vpc_subnet.exam_subnet.id
  }

  deletion_protection = false
}


# PostgreSQL user required by the exam assignment

resource "yandex_mdb_postgresql_user" "db_user" {
  cluster_id = yandex_mdb_postgresql_cluster.exam_postgres.id
  name       = "db_user"
  password   = var.db_password
}


# PostgreSQL database required by the exam assignment

resource "yandex_mdb_postgresql_database" "app_db" {
  cluster_id = yandex_mdb_postgresql_cluster.exam_postgres.id
  name       = "app_db"
  owner      = yandex_mdb_postgresql_user.db_user.name
}