output "atlas_cluster_connection_string" { 
    value = mongodbatlas_advanced_cluster.main.connection_strings.0.standard_srv 
}

output "project_name"  { 
    value = mongodbatlas_project.main.name 
}

output "mongodb_endpoint_service_name" {
    value = mongodbatlas_privatelink_endpoint.main.endpoint_service_name
}

