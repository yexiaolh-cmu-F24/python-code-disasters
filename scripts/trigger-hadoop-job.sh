#!/bin/bash
# Script to trigger Hadoop job based on SonarQube analysis results
# This can be called independently or as part of Jenkins pipeline

set -e

# Configuration
PROJECT_ID="${GCP_PROJECT_ID}"
CLUSTER_NAME="${HADOOP_CLUSTER_NAME}"
REGION="${HADOOP_REGION:-us-central1}"
SONARQUBE_URL="${SONARQUBE_URL:-http://localhost:9000}"
PROJECT_KEY="${SONARQUBE_PROJECT_KEY:-python-code-disasters}"
OUTPUT_BUCKET="${OUTPUT_BUCKET}"
STAGING_BUCKET="${STAGING_BUCKET}"
REPO_PATH="${REPO_PATH:-.}"

# Function to check for blocker issues in SonarQube
check_blocker_issues() {
    echo "Checking for blocker issues in SonarQube..."
    
    # Query SonarQube API for blocker issues
    BLOCKER_COUNT=$(curl -s -u admin:admin \
        "${SONARQUBE_URL}/api/issues/search?componentKeys=${PROJECT_KEY}&severities=BLOCKER&resolved=false" \
        | grep -o '"total":[0-9]*' | cut -d':' -f2 || echo "0")
    
    echo "Blocker issues found: $BLOCKER_COUNT"
    
    if [ "$BLOCKER_COUNT" -eq "0" ]; then
        echo "✓ No blocker issues found."
        return 0
    else
        echo "✗ Found $BLOCKER_COUNT blocker issue(s)."
        return 1
    fi
}

# Function to upload code to GCS
upload_code_to_gcs() {
    echo "Uploading code to GCS..."
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    GCS_INPUT_PATH="gs://${OUTPUT_BUCKET}/repo-code-${TIMESTAMP}"
    
    # Find and upload all Python files
    gsutil -m cp -r "${REPO_PATH}/"*.py "${GCS_INPUT_PATH}/" || true
    gsutil -m cp -r "${REPO_PATH}/"**/*.py "${GCS_INPUT_PATH}/" || true
    
    echo "Code uploaded to: $GCS_INPUT_PATH"
    echo "$GCS_INPUT_PATH"
}

# Function to run Hadoop job
run_hadoop_job() {
    local input_path=$1
    local output_path=$2
    
    echo "Submitting Hadoop job..."
    echo "Input: $input_path"
    echo "Output: $output_path"
    
    gcloud dataproc jobs submit pyspark \
        "gs://${STAGING_BUCKET}/jobs/line_counter_pyspark.py" \
        --cluster="${CLUSTER_NAME}" \
        --region="${REGION}" \
        --project="${PROJECT_ID}" \
        -- "${input_path}" "${output_path}"
    
    echo "Hadoop job submitted successfully!"
}

# Function to display results
display_results() {
    local output_path=$1
    
    echo ""
    echo "========================================"
    echo "HADOOP JOB RESULTS"
    echo "========================================"
    echo ""
    
    gsutil cat "${output_path}/part-*" 2>/dev/null || echo "No results found yet. Job may still be running."
    
    echo ""
    echo "========================================"
    echo "Full results available at: $output_path"
    echo "========================================"
}

# Main execution
main() {
    echo "========================================="
    echo "Hadoop Job Trigger Script"
    echo "========================================="
    
    # Check for blocker issues
    if check_blocker_issues; then
        echo ""
        echo "Proceeding with Hadoop job execution..."
        
        # Upload code to GCS
        INPUT_PATH=$(upload_code_to_gcs)
        
        # Generate output path
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        OUTPUT_PATH="gs://${OUTPUT_BUCKET}/results/${TIMESTAMP}"
        
        # Run Hadoop job
        run_hadoop_job "$INPUT_PATH" "$OUTPUT_PATH"
        
        # Wait a bit for job to complete
        echo "Waiting for job to complete..."
        sleep 30
        
        # Display results
        display_results "$OUTPUT_PATH"
        
        echo ""
        echo "✓ Hadoop job completed successfully!"
        exit 0
    else
        echo ""
        echo "✗ Hadoop job NOT executed due to blocker issues."
        echo "Please fix the blocker issues in SonarQube and try again."
        exit 1
    fi
}

# Run main function
main


