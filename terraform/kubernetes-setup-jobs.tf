# Kubernetes Jobs for Automated Setup
# These jobs run automatically after services are deployed

# ConfigMap for SonarQube setup script
resource "kubernetes_config_map" "sonarqube_setup_script" {
  metadata {
    name      = "sonarqube-setup-script"
    namespace = kubernetes_namespace.sonarqube.metadata[0].name
  }

  data = {
    "setup.sh" = file("${path.module}/../scripts/automate-sonarqube-setup.sh")
  }

  depends_on = [kubernetes_deployment.sonarqube]
}

# Job to setup SonarQube automatically
resource "kubernetes_job" "sonarqube_setup" {
  metadata {
    name      = "sonarqube-setup"
    namespace = kubernetes_namespace.sonarqube.metadata[0].name
  }

  spec {
    template {
      metadata {
        labels = {
          app = "sonarqube-setup"
        }
      }

      spec {
        container {
          name  = "setup"
          image = "curlimages/curl:latest"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOT
              apk add --no-cache bash
              cd /tmp
              cat /config/setup.sh > setup.sh
              chmod +x setup.sh
              export SONARQUBE_URL="http://sonarqube-service.sonarqube.svc.cluster.local:9000"
              export SONAR_ADMIN_USER="admin"
              export SONAR_ADMIN_PASS="admin"
              export SONAR_NEW_PASS="admin123"
              export SONAR_PROJECT_KEY="Python-Code-Disasters"
              export SONAR_PROJECT_NAME="Python Code Disasters"
              export SONAR_TOKEN_NAME="jenkins-token"
              ./setup.sh
            EOT
          ]

          volume_mount {
            name       = "config"
            mount_path = "/config"
          }

          env {
            name  = "SONARQUBE_URL"
            value = "http://sonarqube-service.sonarqube.svc.cluster.local:9000"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.sonarqube_setup_script.metadata[0].name
          }
        }

        restart_policy = "Never"
      }
    }

    backoff_limit = 3
  }

  depends_on = [
    kubernetes_deployment.sonarqube,
    kubernetes_service.sonarqube_service,
    kubernetes_config_map.sonarqube_setup_script
  ]
}

