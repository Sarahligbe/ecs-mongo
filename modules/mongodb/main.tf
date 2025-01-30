data "mongodbatlas_roles_org_id" "test" {
}

resource "mongodbatlas_project" "main" {
  name   = var.mongodb_project_name
  org_id = data.mongodbatlas_roles_org_id.test.org_id
}

resource "mongodbatlas_database_user" "db-user" {
  username = var.ecs_role_arn
  aws_iam_type       = "ROLE"
  project_id = mongodbatlas_project.atlas-project.id
  auth_database_name = "$external"
  roles {
    role_name     = "readWrite"
    database_name = "${var.mongodb_project_name}-db"
  }
}

resource "mongodbatlas_advanced_cluster" "main" {
  project_id   = mongodbatlas_project.main.id
  name         = var.mongodb_cluster_name
  cluster_type = "REPLICASET"
  backup_enabled = true

  replication_specs {
    region_configs {
      electable_specs {
        instance_size = var.instance_size
        node_count    = var.node_count
      }
      provider_name         = "AWS"
      region_name           = var.region
      priority              = 7
    }
  }
}

resource "mongodbatlas_privatelink_endpoint" "main" {
  project_id    = mongodbatlas_project.main.id
  provider_name = "AWS"
  region        = var.region
}

resource "mongodbatlas_privatelink_endpoint_service" "main" {
  project_id          = mongodbatlas_privatelink_endpoint.main.project_id
  private_link_id     = mongodbatlas_privatelink_endpoint.main.id
  endpoint_service_id = var.vpc_endpoint
  provider_name       = "AWS"
}