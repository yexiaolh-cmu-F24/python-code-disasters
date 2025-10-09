variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "credentials_json" {
  type        = string
  description = "Credentials JSON file"
  default     = "./terraform.json"
}


variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "gke_cluster_name" {
  type    = string
  default = "ci-gke"
}

variable "gke_node_count" {
  type    = number
  default = 2
}

variable "gke_machine_type" {
  type    = string
  default = "e2-standard-4"
}


# Dataproc
variable "dataproc_cluster_name" {
  type    = string
  default = "hadoop-dp"
}

variable "dataproc_master_type" {
  type    = string
  default = "e2-standard-4"
}
variable "dataproc_worker_type" {
  type    = string
  default = "e2-standard-4"
}

variable "sonar_project_key" {
  type    = string
  default = "python-code-disasters"
}
variable "sonar_project_name" {
  type    = string
  default = "python-code-disasters"
}
