#!/bin/bash
# Script to view Hadoop MapReduce job results
# Usage: ./view-results.sh [output_path]
# If no path provided, shows the latest results

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get project ID from terraform.tfvars if available
if [ -f "../terraform/terraform.tfvars" ]; then
    PROJECT_ID=$(grep 'project_id' ../terraform/terraform.tfvars | cut -d'"' -f2 | head -1)
    if [ -z "$PROJECT_ID" ]; then
        PROJECT_ID=$(grep '^project_id' ../terraform/terraform.tfvars | cut -d'=' -f2 | tr -d ' "' | head -1)
    fi
else
    PROJECT_ID="${GCP_PROJECT_ID}"
fi

OUTPUT_BUCKET="${OUTPUT_BUCKET:-${PROJECT_ID}-hadoop-output}"

if [ -z "$1" ]; then
    # Get the latest results directory
    echo -e "${BLUE}Finding latest results...${NC}"
    LATEST_PATH=$(gsutil ls -l "gs://${OUTPUT_BUCKET}/results/" 2>/dev/null | grep "DIRECTORY" | tail -1 | awk '{print $3}' | sed 's|gs://||' | sed 's|/$||')
    
    if [ -z "$LATEST_PATH" ]; then
        echo -e "${YELLOW}No results found. Listing all available results:${NC}"
        gsutil ls "gs://${OUTPUT_BUCKET}/results/" 2>/dev/null || echo "No results directory found"
        exit 1
    fi
    
    OUTPUT_PATH="gs://${LATEST_PATH}"
else
    # If path doesn't start with gs://, assume it's relative to the bucket
    if [[ "$1" =~ ^gs:// ]]; then
        OUTPUT_PATH="$1"
    else
        OUTPUT_PATH="gs://${OUTPUT_BUCKET}/$1"
    fi
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}          Hadoop MapReduce Job Results${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Results Path: ${OUTPUT_PATH}${NC}"
echo ""

# Fetch and display results
echo -e "${YELLOW}Line counts for Python files:${NC}"
echo ""

# Try to get results using gcloud storage (preferred)
if command -v gcloud &> /dev/null; then
    # Use eval to prevent shell glob expansion
    eval "gcloud storage ls '${OUTPUT_PATH}/part-*' 2>/dev/null" | while read -r file; do
        gcloud storage cat "$file" 2>/dev/null
    done | sort || {
        echo "Attempting to list files in results directory..."
        gcloud storage ls "${OUTPUT_PATH}/" 2>/dev/null || echo "Could not access results"
    }
else
    # Fallback to gsutil - use eval to prevent shell glob expansion
    eval "gsutil ls '${OUTPUT_PATH}/part-*' 2>/dev/null" | while read -r file; do
        gsutil cat "$file" 2>/dev/null
    done | sort || {
        echo "Attempting to list files in results directory..."
        gsutil ls "${OUTPUT_PATH}/" 2>/dev/null || echo "Could not access results"
    }
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Full results available at: ${OUTPUT_PATH}${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""

# Optional: Display as formatted table
echo -e "${BLUE}Formatted Results:${NC}"
echo ""

# Collect all results and format them
RESULTS_TEMP=$(mktemp)
if command -v gcloud &> /dev/null; then
    # Use eval to prevent shell glob expansion
    eval "gcloud storage ls '${OUTPUT_PATH}/part-*' 2>/dev/null" | while read -r file; do
        gcloud storage cat "$file" 2>/dev/null >> "$RESULTS_TEMP"
    done
else
    # Use eval to prevent shell glob expansion
    eval "gsutil ls '${OUTPUT_PATH}/part-*' 2>/dev/null" | while read -r file; do
        gsutil cat "$file" 2>/dev/null >> "$RESULTS_TEMP"
    done
fi

# Parse and format results
while IFS= read -r line; do
    line=$(echo "$line" | tr -d '\r')
    # Handle Python tuple format: ('filename.py', count) or ("filename.py", count)
    if [[ $line =~ ^\(\'(.+)\',\ ([0-9]+)\)$ ]] || [[ $line =~ ^\(\"(.+)\",\ ([0-9]+)\)$ ]]; then
        filename="${BASH_REMATCH[1]}"
        count="${BASH_REMATCH[2]}"
        printf "%-50s %10s lines\n" "$filename" "$count"
    # Handle JSON format: {"filename.py": count} or "filename.py": count
    elif [[ $line =~ ^\"(.+)\":\ ([0-9]+)$ ]] || [[ $line =~ ^\{.*\"(.+)\":\ ([0-9]+).*\}$ ]]; then
        filename="${BASH_REMATCH[1]}"
        count="${BASH_REMATCH[2]}"
        printf "%-50s %10s lines\n" "$filename" "$count"
    fi
done < "$RESULTS_TEMP" | sort -k2 -n -r

rm -f "$RESULTS_TEMP"

echo ""

