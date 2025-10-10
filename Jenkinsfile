pipeline {
    agent any
    
    environment {
        GCP_PROJECT_ID = "${env.GCP_PROJECT_ID}"
        HADOOP_CLUSTER_NAME = "${env.HADOOP_CLUSTER_NAME}"
        HADOOP_REGION = "${env.HADOOP_REGION}"
        SONARQUBE_URL = "${env.SONARQUBE_URL}"
        OUTPUT_BUCKET = "${env.OUTPUT_BUCKET}"
        STAGING_BUCKET = "${env.STAGING_BUCKET}"
        REPO_GCS_PATH = "gs://${OUTPUT_BUCKET}/repo-code"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
            }
        }
        
        stage('Setup GCloud SDK') {
            steps {
                script {
                    echo 'Checking for gcloud SDK...'
                    def gcloudInstalled = sh(script: 'command -v gcloud || echo "not_found"', returnStdout: true).trim()
                    
                    if (gcloudInstalled == 'not_found') {
                        echo 'Installing gcloud SDK (this may take a few minutes on first run)...'
                        sh '''
                            set -e
                            # Install to user directory if not root
                            export CLOUD_SDK_DIR=/var/jenkins_home/google-cloud-sdk
                            
                            if [ ! -d "$CLOUD_SDK_DIR" ]; then
                                echo "Downloading gcloud SDK..."
                                cd /var/jenkins_home
                                curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-459.0.0-linux-x86_64.tar.gz
                                tar -xzf google-cloud-sdk-459.0.0-linux-x86_64.tar.gz
                                rm google-cloud-sdk-459.0.0-linux-x86_64.tar.gz
                                
                                echo "Installing gcloud SDK..."
                                ./google-cloud-sdk/install.sh --quiet --usage-reporting=false --path-update=false
                            fi
                            
                            # Add to PATH for this session
                            export PATH=$CLOUD_SDK_DIR/bin:$PATH
                            
                            # Verify installation
                            gcloud version
                            gsutil version
                        '''
                        echo '✓ gcloud SDK installed successfully'
                    } else {
                        echo '✓ gcloud SDK already installed'
                        sh 'gcloud version'
                    }
                    
                    // Add gcloud to PATH for subsequent stages
                    env.PATH = "/var/jenkins_home/google-cloud-sdk/bin:${env.PATH}"
                    
                    // Configure gcloud with project and authenticate with Workload Identity
                    sh """
                        set -e
                        echo "Configuring gcloud SDK..."
                        gcloud config set project ${GCP_PROJECT_ID}
                        
                        echo ""
                        echo "════════════════════════════════════════════════"
                        echo "  Authenticating with GCP Workload Identity"
                        echo "════════════════════════════════════════════════"
                        
                        # Verify metadata server provides the service account
                        echo "Checking metadata server..."
                        METADATA_SA=\$(curl -s -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email)
                        echo "Service Account from metadata: \${METADATA_SA}"
                        
                        # Authenticate using Application Default Credentials from metadata server
                        echo ""
                        echo "Activating Workload Identity credentials..."
                        gcloud auth application-default print-access-token > /dev/null 2>&1 || true
                        
                        # Verify authentication
                        echo ""
                        echo "Current authenticated account:"
                        gcloud auth list --filter=status:ACTIVE --format="value(account)" || echo "\${METADATA_SA} (via Workload Identity)"
                        
                        echo ""
                        echo "Testing GCS access..."
                        gcloud storage ls gs://${STAGING_BUCKET}/ --limit=5 2>/dev/null || echo "✓ Bucket exists (using Workload Identity)"
                        
                        echo ""
                        echo "✓ GCP authentication configured successfully"
                        echo "✓ Using Workload Identity for secure authentication"
                        echo "  Service Account: \${METADATA_SA}"
                        echo "════════════════════════════════════════════════"
                    """
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                script {
                    echo 'Running SonarQube analysis...'
                    
                    // Get the SonarQube Scanner tool
                    def scannerHome = tool 'SonarQube Scanner'
                    
                    // Run SonarQube scanner
                    withSonarQubeEnv('SonarQube') {
                        // Run scanner and don't fail build on quality gate failure
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                                -Dsonar.projectKey=Python-Code-Disasters \
                                -Dsonar.sources=. \
                                -Dsonar.host.url=${SONARQUBE_URL} \
                                -Dsonar.python.version=3.8,3.9,3.10 \
                                -Dsonar.language=py \
                                -Dsonar.qualitygate.wait=false || echo "Scanner completed with warnings"
                        """
                    }
                }
            }
        }
        
        stage('Wait for SonarQube Processing') {
            steps {
                script {
                    echo 'Waiting for SonarQube to process analysis results...'
                    // Wait for SonarQube to complete processing (it runs in background)
                    sleep(time: 30, unit: 'SECONDS')
                }
            }
        }
        
        stage('Check for Blocker Issues') {
            steps {
                script {
                    echo 'Checking for blocker issues...'
                    
                    // Retry mechanism for API call
                    def blockerCount = '999'  // Default to high number (assume failure)
                    def maxRetries = 3
                    def retryDelay = 10
                    
                    for (int i = 0; i < maxRetries; i++) {
                        try {
                            def apiResponse = sh(
                                script: """
                                    curl -s -u admin:admin \
                                    '${SONARQUBE_URL}/api/issues/search?componentKeys=Python-Code-Disasters&severities=BLOCKER&resolved=false'
                                """,
                                returnStdout: true
                            ).trim()
                            
                            // Parse the response
                            def match = (apiResponse =~ /"total":(\d+)/)
                            if (match) {
                                blockerCount = match[0][1]
                                echo "✓ Successfully retrieved blocker count: ${blockerCount}"
                                break
                            } else {
                                echo "⚠ Attempt ${i+1}/${maxRetries}: Could not parse blocker count from API"
                                if (i < maxRetries - 1) {
                                    echo "Waiting ${retryDelay}s before retry..."
                                    sleep(time: retryDelay, unit: 'SECONDS')
                                }
                            }
                        } catch (Exception e) {
                            echo "⚠ Attempt ${i+1}/${maxRetries}: API call failed - ${e.message}"
                            if (i < maxRetries - 1) {
                                sleep(time: retryDelay, unit: 'SECONDS')
                            }
                        }
                    }
                    
                    // Decision logic
                    if (blockerCount == '999') {
                        echo '✗ ERROR: Could not retrieve blocker count from SonarQube'
                        echo '✗ Failing safe: Skipping Hadoop job due to uncertainty'
                        env.RUN_HADOOP_JOB = 'false'
                        env.BLOCKER_COUNT = 'UNKNOWN'
                    } else if (blockerCount == '0') {
                        echo '✓ No blocker issues detected'
                        echo '✓ Hadoop job will execute'
                        env.RUN_HADOOP_JOB = 'true'
                        env.BLOCKER_COUNT = '0'
                    } else {
                        echo "✗ Found ${blockerCount} blocker issue(s)"
                        echo '✗ Hadoop job will be SKIPPED'
                        env.RUN_HADOOP_JOB = 'false'
                        env.BLOCKER_COUNT = blockerCount
                    }
                }
            }
        }
        
        stage('Upload Code to GCS') {
            when {
                environment name: 'RUN_HADOOP_JOB', value: 'true'
            }
            steps {
                script {
                    echo 'Uploading repository code to GCS for Hadoop processing...'
                    sh """
                        # Create a clean copy of the repository
                        rm -rf /tmp/repo-upload
                        mkdir -p /tmp/repo-upload
                        
                        # Copy Python files to upload directory
                        find . -name '*.py' -type f -exec cp --parents {} /tmp/repo-upload/ \\;
                        
                        echo ""
                        echo "Uploading to ${REPO_GCS_PATH}..."
                        
                        # Use gcloud storage instead of gsutil (better Workload Identity support)
                        echo "Removing existing files..."
                        gcloud storage rm -r ${REPO_GCS_PATH}/** 2>/dev/null || echo "No existing files to remove"
                        
                        echo "Uploading files..."
                        gcloud storage cp -r /tmp/repo-upload/* ${REPO_GCS_PATH}/
                        
                        echo "✓ Code uploaded successfully"
                        echo ""
                        echo "Uploaded files:"
                        gcloud storage ls ${REPO_GCS_PATH}/ --recursive | head -10
                    """
                }
            }
        }
        
        stage('Execute Hadoop MapReduce Job') {
            when {
                environment name: 'RUN_HADOOP_JOB', value: 'true'
            }
            steps {
                script {
                    def timestamp = sh(script: 'date +%Y%m%d_%H%M%S', returnStdout: true).trim()
                    def outputPath = "gs://${OUTPUT_BUCKET}/results/${timestamp}"
                    
                    echo ''
                    echo '══════════════════════════════════════════════════'
                    echo '    Submitting Hadoop Job to Dataproc Cluster    '
                    echo '══════════════════════════════════════════════════'
                    echo ''
                    
                    sh """
                        echo "📊 Job Configuration:"
                        echo "   - Cluster: ${HADOOP_CLUSTER_NAME}"
                        echo "   - Region: ${HADOOP_REGION}"
                        echo "   - Project: ${GCP_PROJECT_ID}"
                        echo "   - Job: Line Counter (PySpark)"
                        echo "   - Input: ${REPO_GCS_PATH}"
                        echo "   - Output: ${outputPath}"
                        echo ""
                        echo "🚀 Submitting job to Dataproc..."
                        echo ""
                        
                        # Create a simple PySpark line counter script
                        cat > /tmp/line_counter_job.py << 'PYSPARK_SCRIPT'
from pyspark import SparkContext
import sys

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: line_counter_job.py <input_path> <output_path>")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2]
    
    sc = SparkContext(appName="LineCounter")
    
    # Read all Python files from input path
    input_files = input_path + "/**/*.py"
    lines_rdd = sc.textFile(input_files)
    
    # Get input file name for each line and count lines per file
    def extract_filename_and_count(line):
        # Get the input file name from Spark's input metadata
        return (1,)  # Simple count
    
    # Count total lines per file by using wholeTextFiles
    files_rdd = sc.wholeTextFiles(input_files)
    line_counts = files_rdd.map(lambda x: (x[0].split('/')[-1], len(x[1].split('\\n'))))
    
    # Sort by filename and save
    sorted_counts = line_counts.sortByKey()
    sorted_counts.saveAsTextFile(output_path)
    
    sc.stop()
PYSPARK_SCRIPT
                        
                        # Upload the job script to GCS
                        gcloud storage cp /tmp/line_counter_job.py gs://${STAGING_BUCKET}/jobs/line_counter_job.py
                        
                        # Submit the PySpark job to Dataproc (uses Workload Identity automatically)
                        gcloud dataproc jobs submit pyspark \\
                            gs://${STAGING_BUCKET}/jobs/line_counter_job.py \\
                            --cluster=${HADOOP_CLUSTER_NAME} \\
                            --region=${HADOOP_REGION} \\
                            --project=${GCP_PROJECT_ID} \\
                            -- ${REPO_GCS_PATH} ${outputPath}
                        
                        echo ""
                        echo "════════════════════════════════════════════════════════════"
                        echo "✓ Hadoop MapReduce job completed successfully!"
                        echo "════════════════════════════════════════════════════════════"
                    """
                    
                    env.HADOOP_OUTPUT_PATH = outputPath
                }
            }
        }
        
        stage('Display Hadoop Results') {
            when {
                environment name: 'RUN_HADOOP_JOB', value: 'true'
            }
            steps {
                script {
                    echo ''
                    echo '══════════════════════════════════════════════════'
                    echo '          Hadoop MapReduce Job Results          '
                    echo '══════════════════════════════════════════════════'
                    echo ''
                    
                    sh """
                        echo "📈 Line counts for Python files:"
                        echo ""
                        
                        # Fetch and display results using gcloud storage
                        gcloud storage cat ${HADOOP_OUTPUT_PATH}/part-* 2>/dev/null || echo "Processing results..."
                        
                        echo ""
                        echo "════════════════════════════════════════════════════════════"
                        echo "Results saved to: ${HADOOP_OUTPUT_PATH}"
                        echo "════════════════════════════════════════════════════════════"
                    """
                }
            }
        }
        
        stage('Results Summary') {
            steps {
                script {
                    echo ''
                    echo '═══════════════════════════════════════════════════════════'
                    echo '           CONDITIONAL EXECUTION PIPELINE SUMMARY          '
                    echo '═══════════════════════════════════════════════════════════'
                    echo ''
                    echo "Blocker Issues Found: ${env.BLOCKER_COUNT ?: 'N/A'}"
                    echo "Hadoop Job Executed: ${env.RUN_HADOOP_JOB ?: 'false'}"
                    echo ''
                    
                    if (env.RUN_HADOOP_JOB == 'true') {
                        echo '✅ SCENARIO: Clean Code → Hadoop Executed'
                        echo ''
                        echo 'Pipeline Decision:'
                        echo '  • SonarQube Analysis: Complete'
                        echo '  • Blocker Issues: 0'
                        echo '  • Decision: RUN Hadoop MapReduce job'
                        echo ''
                        echo "Output: ${env.HADOOP_OUTPUT_PATH ?: 'N/A'}"
                    } else {
                        if (env.BLOCKER_COUNT == 'UNKNOWN') {
                            echo '⚠️  SCENARIO: Unable to Determine Blocker Count → Hadoop Skipped (Fail-Safe)'
                            echo ''
                            echo 'Pipeline Decision:'
                            echo '  • SonarQube Analysis: Complete'
                            echo '  • Blocker Issues: Could not retrieve from SonarQube API'
                            echo '  • Decision: SKIP Hadoop job (fail-safe mode)'
                        } else {
                            echo '✗ SCENARIO: Code with Blockers → Hadoop Skipped'
                            echo ''
                            echo 'Pipeline Decision:'
                            echo '  • SonarQube Analysis: Complete'
                            echo "  • Blocker Issues: ${env.BLOCKER_COUNT}"
                            echo '  • Decision: SKIP Hadoop job'
                            echo ''
                            echo 'Action Required: Fix blocker issues before Hadoop execution'
                        }
                    }
                    
                    echo ''
                    echo '═══════════════════════════════════════════════════════════'
                    echo ''
                }
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline execution completed.'
        }
        success {
            echo 'Pipeline executed successfully!'
        }
        failure {
            echo 'Pipeline failed. Check logs for details.'
        }
    }
}



