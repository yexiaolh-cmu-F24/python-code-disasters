#!/bin/bash
# Create Jenkins pipeline job via REST API with proper authentication

set -e

JENKINS_URL="http://136.114.99.232:8080/jenkins"
JOB_NAME="python-code-analysis"
GITHUB_REPO="https://github.com/yexiaolh-cmu-F24/python-code-disasters"

echo "========================================="
echo "Creating Jenkins Pipeline Job via API"
echo "========================================="
echo "Jenkins URL: $JENKINS_URL"
echo "Job Name: $JOB_NAME"
echo ""

# Get CSRF crumb
echo "Getting CSRF token..."
CSRF_RESPONSE=$(curl -s -c /tmp/jenkins_cookies.txt "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,\":\",//crumb)" 2>/dev/null || echo "")

if [ -z "$CSRF_RESPONSE" ]; then
    echo "⚠ Could not get CSRF token. Trying without it..."
    CSRF_HEADER=""
else
    CSRF_HEADER=$(echo "$CSRF_RESPONSE" | cut -d: -f1)
    CSRF_VALUE=$(echo "$CSRF_RESPONSE" | cut -d: -f2)
    CSRF_HEADER="$CSRF_HEADER: $CSRF_VALUE"
    echo "✓ Got CSRF token"
fi

# Create job config XML
JOB_CONFIG=$(cat <<EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job@2.6">
  <description>CI/CD pipeline for Python code analysis with SonarQube and Hadoop</description>
  <keepDependencies>false</keepDependencies>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.6">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@5.8.0">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>${GITHUB_REPO}</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>false</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF
)

echo "Creating pipeline job..."

# Create job with CSRF token
if [ -n "$CSRF_HEADER" ]; then
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -b /tmp/jenkins_cookies.txt \
        -H "$CSRF_HEADER" \
        -H "Content-Type: application/xml" \
        -d "$JOB_CONFIG" \
        "$JENKINS_URL/createItem?name=$JOB_NAME" 2>/dev/null)
else
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/xml" \
        -d "$JOB_CONFIG" \
        "$JENKINS_URL/createItem?name=$JOB_NAME" 2>/dev/null)
fi

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

rm -f /tmp/jenkins_cookies.txt

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✓ Pipeline job created successfully!"
    echo ""
    echo "Job URL: $JENKINS_URL/job/$JOB_NAME"
    echo ""
    echo "You can now:"
    echo "1. View the job: $JENKINS_URL/job/$JOB_NAME"
    echo "2. Click 'Build Now' to test the pipeline"
else
    echo "✗ Failed to create pipeline job"
    echo "HTTP Code: $HTTP_CODE"
    if [ -n "$BODY" ]; then
        echo "Response: $BODY"
    fi
    echo ""
    echo "Troubleshooting:"
    echo "- Make sure Pipeline plugin is installed"
    echo "- Check if job name already exists"
    echo "- Try accessing Jenkins UI directly"
    exit 1
fi

