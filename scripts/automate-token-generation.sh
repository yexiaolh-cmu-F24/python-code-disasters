#!/bin/bash
# Automated token generation using port-forwarding
# This bypasses network protection issues

set -e

echo "========================================="
echo "Automated SonarQube Token Generation"
echo "========================================="
echo ""
echo "This script will:"
echo "1. Set up port-forwarding to SonarQube"
echo "2. Generate authentication token automatically"
echo "3. Create project automatically"
echo ""
echo "Prerequisites:"
echo "  - SonarQube password should be admin123"
echo "  - If not, change it manually first"
echo ""

# Start port-forwarding
echo "Step 1: Setting up port-forwarding..."
kubectl port-forward -n sonarqube svc/sonarqube-service 9001:9000 > /tmp/sonarqube-pf.log 2>&1 &
PF_PID=$!
echo "Port-forward PID: $PF_PID"
echo "Waiting for port-forward to be ready..."
sleep 5

# Test connection
if ! curl -s http://localhost:9001/api/system/status > /dev/null 2>&1; then
    echo "✗ Port-forward failed. Check if SonarQube is running."
    kill $PF_PID 2>/dev/null || true
    exit 1
fi

echo "✓ Port-forward is ready"
echo ""

# Run automated setup via port-forward
echo "Step 2: Running automated setup..."
export SONARQUBE_URL="http://localhost:9001"
export SONAR_ADMIN_USER="admin"
export SONAR_ADMIN_PASS="${SONAR_ADMIN_PASS:-Hyxl@20020425}"
export SONAR_NEW_PASS="${SONAR_ADMIN_PASS}"
export SONAR_PROJECT_KEY="Python-Code-Disasters"
export SONAR_PROJECT_NAME="Python Code Disasters"
export SONAR_TOKEN_NAME="jenkins-token"

# Source the setup script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/automate-sonarqube-setup.sh"

# Cleanup
echo ""
echo "Cleaning up port-forward..."
kill $PF_PID 2>/dev/null || true

echo ""
echo "========================================="
echo "✅ Token generation completed!"
echo "========================================="
echo ""
echo "The token is saved in: /tmp/sonarqube-config/token.txt"
echo ""
echo "Next step: Configure Jenkins with this token"
echo "  (This can be automated via Jenkins init scripts)"

