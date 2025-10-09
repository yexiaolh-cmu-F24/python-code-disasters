resource "google_dataproc_cluster" "hadoop" {
  name   = var.dataproc_cluster_name
  region = var.region

  cluster_config {
      master_config {
        num_instances    = 1
        machine_type     = var.dataproc_master_type
      }
      worker_config {
      num_instances    = 2
      machine_type     = var.dataproc_master_type
      }
  }
}