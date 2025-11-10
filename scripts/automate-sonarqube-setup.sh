#!/bin/bash
# Automated SonarQube Setup Script
# This script automates: password change, project creation, and token generation

set -e

# Detect if running from inside or outside cluster
# Try to get external IP first, fallback to internal service
if command -v kubectl &> /dev/null; then
    SONAR_IP=$(kubectl get svc -n sonarqube sonarqube-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$SONAR_IP" ] && [ "$SONAR_IP" != "pending" ]; then
        SONARQUBE_URL="${SONARQUBE_URL:-http://${SONAR_IP}:9000}"
    else
        # Fallback to internal service URL (if running inside cluster)
        SONARQUBE_URL="${SONARQUBE_URL:-http://sonarqube-service.sonarqube.svc.cluster.local:9000}"
    fi
else
    # No kubectl, use environment variable or default
    SONARQUBE_URL="${SONARQUBE_URL:-http://sonarqube-service.sonarqube.svc.cluster.local:9000}"
fi

ADMIN_USER="${SONAR_ADMIN_USER:-admin}"
ADMIN_PASS="${SONAR_ADMIN_PASS:-admin}"
NEW_PASS="${SONAR_NEW_PASS:-admin123}"
PROJECT_KEY="${SONAR_PROJECT_KEY:-Python-Code-Disasters}"
PROJECT_NAME="${SONAR_PROJECT_NAME:-Python Code Disasters}"
TOKEN_NAME="${SONAR_TOKEN_NAME:-jenkins-token}"

echo "========================================="
echo "Automated SonarQube Setup"
echo "========================================="
echo "SonarQube URL: $SONARQUBE_URL"
echo ""

# Function to wait for SonarQube to be ready
wait_for_sonarqube() {
    echo "Waiting for SonarQube to be ready..."
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f -o /dev/null "$SONARQUBE_URL/api/system/status" 2>/dev/null; then
            local status=$(curl -s "$SONARQUBE_URL/api/system/status" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            if [ "$status" = "UP" ] || [ "$status" = "STARTING" ]; then
                echo "✓ SonarQube is ready (status: $status)"
                return 0
            fi
        fi
        attempt=$((attempt + 1))
        echo "  Attempt $attempt/$max_attempts - waiting 10 seconds..."
        sleep 10
    done
    
    echo "✗ SonarQube did not become ready in time"
    return 1
}

# Function to change admin password
change_admin_password() {
    echo ""
    echo "Step 1: Checking authentication..."
    
    # First, try to authenticate with admin123 (in case user changed it manually)
    if curl -s -u "$ADMIN_USER:$NEW_PASS" "$SONARQUBE_URL/api/authentication/validate" | grep -q '"valid":true'; then
        echo "✓ Authenticated with admin:admin123 (password already changed)"
        ADMIN_PASS="$NEW_PASS"
        return 0
    fi
    
    # Try with default admin password
    if curl -s -u "$ADMIN_USER:$ADMIN_PASS" "$SONARQUBE_URL/api/authentication/validate" | grep -q '"valid":true'; then
        echo "✓ Authenticated with admin:admin (default password)"
        echo "  Attempting to change password to admin123..."
        
        # Try to change password (may fail due to network protection, that's OK)
        local response=$(curl -s -X POST \
            -u "$ADMIN_USER:$ADMIN_PASS" \
            "$SONARQUBE_URL/api/users/change_password?login=$ADMIN_USER&password=$NEW_PASS&previousPassword=$ADMIN_PASS" 2>/dev/null)
        
        # Verify password change
        if curl -s -u "$ADMIN_USER:$NEW_PASS" "$SONARQUBE_URL/api/authentication/validate" | grep -q '"valid":true'; then
            echo "✓ Password changed to admin123"
            ADMIN_PASS="$NEW_PASS"
            return 0
        else
            echo "⚠ Password change failed (network protection may block POST requests)"
            echo "  Continuing with admin:admin - you can change password manually later"
            return 0
        fi
    else
        echo "✗ Cannot authenticate with admin:admin or admin:admin123"
        echo "  Please change password manually in SonarQube UI, then re-run this script"
        return 1
    fi
}

# Function to create project
create_project() {
    echo ""
    echo "Step 2: Creating SonarQube project..."
    
    # Check if project already exists
    if curl -s -u "$ADMIN_USER:$ADMIN_PASS" "$SONARQUBE_URL/api/projects/search?projects=$PROJECT_KEY" | grep -q "\"key\":\"$PROJECT_KEY\""; then
        echo "✓ Project '$PROJECT_KEY' already exists"
        return 0
    fi
    
    # Create project
    local response=$(curl -s -X POST \
        -u "$ADMIN_USER:$ADMIN_PASS" \
        -d "project=$PROJECT_KEY&name=$PROJECT_NAME" \
        "$SONARQUBE_URL/api/projects/create" 2>/dev/null)
    
    if echo "$response" | grep -q "error" && ! echo "$response" | grep -q "already exists"; then
        echo "✗ Failed to create project: $response"
        return 1
    else
        echo "✓ Project '$PROJECT_KEY' created successfully"
        return 0
    fi
}

# Function to generate token
generate_token() {
    echo ""
    echo "Step 3: Generating authentication token..."
    
    # Revoke existing token if it exists (ignore errors)
    curl -s -X POST \
        -u "$ADMIN_USER:$ADMIN_PASS" \
        -d "name=$TOKEN_NAME" \
        "$SONARQUBE_URL/api/user_tokens/revoke" > /dev/null 2>&1 || true
    
    # Generate new token
    local response=$(curl -s -X POST \
        -u "$ADMIN_USER:$ADMIN_PASS" \
        -d "name=$TOKEN_NAME" \
        "$SONARQUBE_URL/api/user_tokens/generate" 2>/dev/null)
    
    local token=$(echo "$response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$token" ]; then
        echo "✗ Failed to generate token: $response"
        return 1
    fi
    
    echo "✓ Token generated successfully"
    echo ""
    echo "========================================="
    echo "SonarQube Token (save this!):"
    echo "$token"
    echo "========================================="
    
    # Save token to a file that Jenkins can read
    mkdir -p /tmp/sonarqube-config
    echo "$token" > /tmp/sonarqube-config/token.txt
    echo "$ADMIN_USER" > /tmp/sonarqube-config/username.txt
    
    # Also save as environment variable for Jenkins
    export SONARQUBE_TOKEN="$token"
    
    return 0
}

# Main execution
main() {
    wait_for_sonarqube || exit 1
    change_admin_password
    create_project
    generate_token
    
    echo ""
    echo "========================================="
    echo "SonarQube setup completed successfully!"
    echo "========================================="
    echo ""
    echo "Project Key: $PROJECT_KEY"
    echo "Token saved to: /tmp/sonarqube-config/token.txt"
    echo ""
}

main

