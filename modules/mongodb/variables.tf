variable "mongodb_project_name" {
    type = string
    default = test_project
}

variable "ecs_role_arn" {
    type = string
}

variable "mongodb_cluster_name" {
    type = string
    default = test_cluster
}

variable "instance_size" {
    type = string
    default = "M0"
}

variable "node_count" {
    type = number
    default = 1
}

variable "region" {
    type = string
}

variable "vpc_endpoint" {
    type = string
}