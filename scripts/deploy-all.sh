#!/bin/bash
# Complete deployment script
# This script automates the entire deployment process

set -e

echo "========================================="
echo "Cloud Infrastructure Deployment Script"
echo "========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "$1"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check gcloud
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not found. Please install it first."
        exit 1
    fi
    print_success "gcloud CLI found"
    
    # Check terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform not found. Please install it first."
        exit 1
    fi
    print_success "Terraform found"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install it first."
        exit 1
    fi
    print_success "kubectl found"
    
    # Check terraform.tfvars exists
    if [ ! -f "../terraform/terraform.tfvars" ]; then
        print_error "terraform.tfvars not found. Please create it from terraform.tfvars.example"
        exit 1
    fi
    print_success "terraform.tfvars found"
}

# Get project ID from terraform.tfvars
get_project_id() {
    PROJECT_ID=$(grep 'project_id' ../terraform/terraform.tfvars | cut -d'"' -f2)
    if [ -z "$PROJECT_ID" ]; then
        print_error "Could not find project_id in terraform.tfvars"
        exit 1
    fi
    print_success "Project ID: $PROJECT_ID"
}

# Enable required APIs
enable_apis() {
    print_info "Enabling required GCP APIs..."
    
    gcloud services enable compute.googleapis.com --project=$PROJECT_ID
    gcloud services enable container.googleapis.com --project=$PROJECT_ID
    gcloud services enable dataproc.googleapis.com --project=$PROJECT_ID
    gcloud services enable storage.googleapis.com --project=$PROJECT_ID
    
    print_success "APIs enabled"
}

# Deploy infrastructure with Terraform
deploy_terraform() {
    print_info "Deploying infrastructure with Terraform..."
    
    cd ../terraform
    
    # Initialize
    print_info "Initializing Terraform..."
    terraform init
    
    # Plan
    print_info "Creating deployment plan..."
    terraform plan -out=tfplan
    
    # Apply
    print_info "Applying Terraform configuration..."
    terraform apply tfplan
    
    # Save outputs
    terraform output > ../outputs.txt
    
    cd ../scripts
    
    print_success "Infrastructure deployed"
}

# Configure kubectl
configure_kubectl() {
    print_info "Configuring kubectl..."
    
    REGION=$(grep 'region' ../terraform/terraform.tfvars | cut -d'"' -f2)
    ZONE=$(grep 'zone' ../terraform/terraform.tfvars | cut -d'"' -f2)
    
    if [ -z "$ZONE" ]; then
        ZONE="us-central1-a"
    fi
    
    gcloud container clusters get-credentials jenkins-sonarqube-cluster \
        --zone $ZONE \
        --project $PROJECT_ID
    
    print_success "kubectl configured"
}

# Wait for services to be ready
wait_for_services() {
    print_info "Waiting for services to be ready..."
    
    # Wait for Jenkins
    print_info "Waiting for Jenkins LoadBalancer..."
    kubectl wait --for=condition=available --timeout=300s deployment/jenkins -n jenkins || true
    
    # Wait for SonarQube
    print_info "Waiting for SonarQube LoadBalancer..."
    kubectl wait --for=condition=available --timeout=300s deployment/sonarqube -n sonarqube || true
    
    # Wait a bit more for LoadBalancer IPs
    print_info "Waiting for LoadBalancer IPs to be assigned..."
    sleep 60
    
    print_success "Services are ready"
}

# Get service URLs
get_service_urls() {
    print_info "Getting service URLs..."
    
    # Get Jenkins IP
    JENKINS_IP=$(kubectl get svc jenkins-service -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    
    # Get SonarQube IP
    SONARQUBE_IP=$(kubectl get svc sonarqube-service -n sonarqube -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
    
    # Save URLs
    cat > ../urls.txt << EOF
JENKINS_URL=http://$JENKINS_IP:8080
SONARQUBE_URL=http://$SONARQUBE_IP:9000

Access Instructions:
====================

Jenkins:
--------
URL: http://$JENKINS_IP:8080

To get initial password:
kubectl exec -n jenkins \$(kubectl get pod -n jenkins -l app=jenkins -o jsonpath="{.items[0].metadata.name}") -- cat /var/jenkins_home/secrets/initialAdminPassword

SonarQube:
----------
URL: http://$SONARQUBE_IP:9000
Default credentials: admin/admin

Hadoop Cluster:
---------------
Name: hadoop-cluster
Region: us-central1

View cluster:
gcloud dataproc clusters describe hadoop-cluster --region=us-central1

Results Bucket:
---------------
gs://$PROJECT_ID-hadoop-output/results/

View results:
gsutil ls gs://$PROJECT_ID-hadoop-output/results/
EOF
    
    print_success "Service URLs saved to urls.txt"
}

# Display summary
display_summary() {
    echo ""
    echo "========================================="
    echo "Deployment Complete!"
    echo "========================================="
    echo ""
    
    if [ "$JENKINS_IP" != "pending" ]; then
        print_success "Jenkins: http://$JENKINS_IP:8080"
    else
        print_warning "Jenkins: IP still pending (check with: kubectl get svc -n jenkins)"
    fi
    
    if [ "$SONARQUBE_IP" != "pending" ]; then
        print_success "SonarQube: http://$SONARQUBE_IP:9000"
    else
        print_warning "SonarQube: IP still pending (check with: kubectl get svc -n sonarqube)"
    fi
    
    echo ""
    echo "Next Steps:"
    echo "1. Configure SonarQube (see QUICKSTART.md)"
    echo "2. Configure Jenkins (see QUICKSTART.md)"
    echo "3. Setup GitHub webhook (see QUICKSTART.md)"
    echo "4. Test the pipeline"
    echo ""
    echo "All details saved to urls.txt"
    echo "========================================="
}

# Main execution
main() {
    check_prerequisites
    get_project_id
    enable_apis
    deploy_terraform
    configure_kubectl
    wait_for_services
    get_service_urls
    display_summary
}

# Run main function
main


