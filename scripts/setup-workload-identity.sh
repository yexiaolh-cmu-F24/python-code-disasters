#!/bin/bash
set -e

echo "════════════════════════════════════════════════════════════"
echo "  Setting up Workload Identity for Jenkins"
echo "════════════════════════════════════════════════════════════"
echo ""

# Configuration
PROJECT_ID="elegant-cipher-471600-m2"
CLUSTER_NAME="jenkins-sonarqube-cluster"
ZONE="us-central1-a"
REGION="us-central1"

echo "📋 Configuration:"
echo "   Project: $PROJECT_ID"
echo "   Cluster: $CLUSTER_NAME"
echo "   Zone: $ZONE"
echo ""

# Step 1: Apply Terraform changes
echo "Step 1: Applying Terraform changes..."
echo "────────────────────────────────────────────────────────────"
cd "$(dirname "$0")/../terraform"

echo "Running terraform plan..."
terraform plan -out=tfplan

read -p "Review the plan above. Apply changes? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Aborted by user"
    exit 1
fi

echo "Applying terraform..."
terraform apply tfplan
rm tfplan

echo "✓ Terraform changes applied"
echo ""

# Step 2: Get cluster credentials
echo "Step 2: Getting cluster credentials..."
echo "────────────────────────────────────────────────────────────"
gcloud container clusters get-credentials $CLUSTER_NAME \
    --zone=$ZONE \
    --project=$PROJECT_ID

echo "✓ Cluster credentials configured"
echo ""

# Step 3: Restart Jenkins pod
echo "Step 3: Restarting Jenkins pod..."
echo "────────────────────────────────────────────────────────────"
echo "Current Jenkins pods:"
kubectl get pods -n jenkins

echo ""
echo "Deleting Jenkins pod to pick up new service account..."
kubectl delete pod -n jenkins -l app=jenkins

echo "Waiting for Jenkins to restart..."
kubectl wait --for=condition=ready pod -l app=jenkins -n jenkins --timeout=300s

echo "✓ Jenkins pod restarted"
echo ""

# Step 4: Verify setup
echo "Step 4: Verifying Workload Identity setup..."
echo "────────────────────────────────────────────────────────────"

echo "✓ GCP Service Account:"
gcloud iam service-accounts list --project=$PROJECT_ID | grep jenkins || echo "  (checking...)"

echo ""
echo "✓ Kubernetes Service Account annotation:"
kubectl get sa jenkins -n jenkins -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}' || echo "  (not set)"

echo ""
echo "✓ Jenkins pod status:"
kubectl get pods -n jenkins

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Workload Identity Setup Complete!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "1. Open Jenkins UI and trigger a build"
echo "2. Check the 'Setup GCloud SDK' stage"
echo "3. Verify authentication shows: jenkins-workload-identity@..."
echo "4. Confirm GCS upload and Hadoop job submission work"
echo ""
echo "Jenkins URL: http://$(kubectl get svc jenkins-service -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080"
echo ""

