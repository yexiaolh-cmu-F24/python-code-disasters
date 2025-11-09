#!/bin/bash
# Master script to run all automated setup
# This script coordinates SonarQube and Jenkins setup

set -e

echo "========================================="
echo "Automated CI/CD Pipeline Setup"
echo "========================================="
echo ""

# Get configuration from environment or defaults
# Try to detect SonarQube external IP
if command -v kubectl &> /dev/null; then
    SONAR_IP=$(kubectl get svc -n sonarqube sonarqube-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$SONAR_IP" ] && [ "$SONAR_IP" != "pending" ]; then
        SONARQUBE_URL="${SONARQUBE_URL:-http://${SONAR_IP}:9000}"
        echo "Using SonarQube external IP: $SONARQUBE_URL"
    else
        SONARQUBE_URL="${SONARQUBE_URL:-http://sonarqube-service.sonarqube.svc.cluster.local:9000}"
        echo "SonarQube IP not ready yet, will use internal service URL"
    fi
else
    SONARQUBE_URL="${SONARQUBE_URL:-http://sonarqube-service.sonarqube.svc.cluster.local:9000}"
fi

GITHUB_REPO_URL="${GITHUB_REPO_URL:-}"
GCP_PROJECT_ID="${GCP_PROJECT_ID:-}"

# Try to get from terraform.tfvars if not set
if [ -z "$GITHUB_REPO_URL" ] && [ -f "../terraform/terraform.tfvars" ]; then
    GITHUB_REPO_URL=$(grep 'github_repo_url' ../terraform/terraform.tfvars | cut -d'"' -f2 | head -1)
    if [ -z "$GITHUB_REPO_URL" ]; then
        GITHUB_REPO_URL=$(grep '^github_repo_url' ../terraform/terraform.tfvars | cut -d'=' -f2 | tr -d ' "' | head -1)
    fi
fi

if [ -z "$GCP_PROJECT_ID" ] && [ -f "../terraform/terraform.tfvars" ]; then
    GCP_PROJECT_ID=$(grep 'project_id' ../terraform/terraform.tfvars | cut -d'"' -f2 | head -1)
    if [ -z "$GCP_PROJECT_ID" ]; then
        GCP_PROJECT_ID=$(grep '^project_id' ../terraform/terraform.tfvars | cut -d'=' -f2 | tr -d ' "' | head -1)
    fi
fi

export GITHUB_REPO_URL
export GCP_PROJECT_ID

# Step 1: Setup SonarQube
echo "Step 1: Setting up SonarQube..."
export SONARQUBE_URL
export SONAR_ADMIN_USER="${SONAR_ADMIN_USER:-admin}"
export SONAR_ADMIN_PASS="${SONAR_ADMIN_PASS:-admin}"
export SONAR_NEW_PASS="${SONAR_NEW_PASS:-admin123}"
export SONAR_PROJECT_KEY="${SONAR_PROJECT_KEY:-Python-Code-Disasters}"
export SONAR_PROJECT_NAME="${SONAR_PROJECT_NAME:-Python Code Disasters}"
export SONAR_TOKEN_NAME="${SONAR_TOKEN_NAME:-jenkins-token}"

# Run SonarQube setup
if [ -f "automate-sonarqube-setup.sh" ]; then
    bash automate-sonarqube-setup.sh
    SONAR_TOKEN=$(cat /tmp/sonarqube-config/token.txt 2>/dev/null || echo "")
    export SONARQUBE_TOKEN="$SONAR_TOKEN"
else
    echo "⚠ SonarQube setup script not found"
fi

echo ""
echo "Step 2: Setting up Jenkins..."

# Wait for Jenkins to be ready
echo "Waiting for Jenkins to be ready..."

# Try to get Jenkins external IP
if command -v kubectl &> /dev/null; then
    JENKINS_IP=$(kubectl get svc -n jenkins jenkins-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$JENKINS_IP" ] && [ "$JENKINS_IP" != "pending" ]; then
        JENKINS_URL="${JENKINS_URL:-http://${JENKINS_IP}:8080}"
        echo "Using Jenkins external IP: $JENKINS_URL"
    else
        JENKINS_URL="${JENKINS_URL:-http://jenkins-service.jenkins.svc.cluster.local:8080}"
        echo "Jenkins IP not ready yet, will use internal service URL"
    fi
else
    JENKINS_URL="${JENKINS_URL:-http://jenkins-service.jenkins.svc.cluster.local:8080}"
fi

max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    # Try both with and without /jenkins prefix
    if curl -s -f -o /dev/null "$JENKINS_URL/jenkins/login" 2>/dev/null || \
       curl -s -f -o /dev/null "$JENKINS_URL/login" 2>/dev/null || \
       curl -s -f -o /dev/null "$JENKINS_URL" 2>/dev/null; then
        echo "✓ Jenkins is ready at $JENKINS_URL"
        # Update JENKINS_URL to include /jenkins prefix if needed
        if curl -s -f -o /dev/null "$JENKINS_URL/jenkins/login" 2>/dev/null; then
            JENKINS_URL="${JENKINS_URL}/jenkins"
        fi
        break
    fi
    attempt=$((attempt + 1))
    if [ $((attempt % 6)) -eq 0 ]; then
        echo "  Still waiting... (attempt $attempt/$max_attempts)"
    fi
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    echo "⚠ Jenkins did not become ready in time"
    echo "  You may need to check Jenkins pod status: kubectl get pods -n jenkins"
    echo "  Or access Jenkins directly at: http://<jenkins-ip>:8080"
fi

# Get Jenkins CLI JAR
JENKINS_CLI_JAR="/tmp/jenkins-cli.jar"
if [ ! -f "$JENKINS_CLI_JAR" ]; then
    echo "Downloading Jenkins CLI..."
    # Try with /jenkins prefix first, then without
    curl -s -o "$JENKINS_CLI_JAR" "$JENKINS_URL/jnlpJars/jenkins-cli.jar" 2>/dev/null || \
    curl -s -o "$JENKINS_CLI_JAR" "${JENKINS_URL%/jenkins}/jnlpJars/jenkins-cli.jar" 2>/dev/null || {
        echo "⚠ Could not download Jenkins CLI, trying alternative method"
    }
fi

# Run Jenkins setup via Groovy script
if [ -f "automate-jenkins-setup.groovy" ]; then
    export SONARQUBE_URL
    export SONARQUBE_TOKEN
    export GITHUB_REPO_URL
    export GCP_PROJECT_ID
    
    # Try to run via Jenkins CLI
    if [ -f "$JENKINS_CLI_JAR" ]; then
        # Get initial admin password
        JENKINS_POD=$(kubectl get pod -n jenkins -l app=jenkins -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")
        if [ -n "$JENKINS_POD" ]; then
            JENKINS_PASSWORD=$(kubectl exec -n jenkins "$JENKINS_POD" -- cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "admin")
            
            java -jar "$JENKINS_CLI_JAR" -s "$JENKINS_URL" -auth admin:"$JENKINS_PASSWORD" groovy automate-jenkins-setup.groovy 2>/dev/null || {
                echo "⚠ Jenkins CLI execution failed, setup may need manual completion"
            }
        fi
    else
        echo "⚠ Jenkins CLI not available, setup may need manual completion"
    fi
else
    echo "⚠ Jenkins setup script not found"
fi

echo ""
echo "========================================="
echo "Automated setup completed!"
echo "========================================="
echo ""
echo "If any steps failed, you may need to complete them manually."
echo "See CONFIGURATION_GUIDE.md for manual setup instructions."
echo ""

