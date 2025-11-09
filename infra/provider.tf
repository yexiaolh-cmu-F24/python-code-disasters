provider "google" {
    project = var.project_id
    region  = var.region
    zone    = var.zone
    credentials = file(var.credentials_json)
}

data "google_client_config" "default" {}

provider "kubernetes" {
    host = "https://${google_container_cluster.ci.endpoint}"
    token = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.ci.master_auth[0].cluster_ca_certificate)
  
}
