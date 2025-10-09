resource "google_container_cluster" "ci" {
  name                     = var.gke_cluster_name
  location                 = var.zone
  remove_default_node_pool = true
  initial_node_count       = 1
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "ci_nodes" {
  name       = "default-pool"
  location   = var.zone
  cluster    = google_container_cluster.ci.name
  node_count = var.gke_node_count
  node_config {
    preemptible  = false
    machine_type = var.gke_machine_type
    disk_type    = "pd-standard"
    disk_size_gb = 30 
    labels       = { role = "ci" }
  }
}

resource "null_resource" "deploy_services" {
  depends_on = [
    google_container_node_pool.ci_nodes
  ]
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${google_container_cluster.ci.name} --zone=${google_container_cluster.ci.location}"
  }

  provisioner "local-exec" {
    command = <<EOT
    cd ${path.module}/.. &&
    kubectl apply -f ./scripts/namespace.yaml &&
    kubectl apply -f ./scripts/secrets.yaml &&
    kubectl apply -f ./scripts/postgres.yaml &&
    kubectl apply -f ./scripts/sonarqube.yaml &&
    kubectl apply -f ./scripts/jenkins.yaml
    EOT
  }

}
