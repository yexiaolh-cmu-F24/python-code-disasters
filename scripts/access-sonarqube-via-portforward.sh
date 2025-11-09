#!/bin/bash
# Script to access SonarQube via port forwarding (bypasses network protection)

set -e

echo "========================================="
echo "SonarQube Port Forward Access"
echo "========================================="
echo ""
echo "This script sets up port forwarding to access SonarQube"
echo "bypassing network protection issues."
echo ""
echo "After running this, access SonarQube at:"
echo "  http://localhost:9000"
echo ""
echo "Press Ctrl+C to stop port forwarding"
echo ""
echo "Starting port forward..."
echo ""

# Get SonarQube pod name
SONAR_POD=$(kubectl get pod -n sonarqube -l app=sonarqube -o jsonpath='{.items[0].metadata.name}')

if [ -z "$SONAR_POD" ]; then
    echo "✗ Could not find SonarQube pod"
    exit 1
fi

echo "Forwarding port 9000 from pod: $SONAR_POD"
echo ""

# Start port forwarding
kubectl port-forward -n sonarqube "$SONAR_POD" 9000:9000

