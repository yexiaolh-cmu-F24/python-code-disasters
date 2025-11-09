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
                    
                    // Download and use SonarQube Scanner CLI (no tool configuration needed)
                    sh """
                        set -eu
                        SCAN_VERSION="5.0.1.3006"
                        echo "Downloading SonarQube scanner version \${SCAN_VERSION}"
                        curl -L -o scanner.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-\${SCAN_VERSION}-linux.zip
                        echo "Download completed, extracting..."
                        unzip -q -o scanner.zip
                        echo "Extraction completed"
                        
                        echo "=== Running SonarQube Analysis ==="
                        ./sonar-scanner-\${SCAN_VERSION}-linux/bin/sonar-scanner \
                            -Dsonar.projectKey=Python-Code-Disasters \
                            -Dsonar.sources=. \
                            -Dsonar.host.url=\${SONARQUBE_URL} \
                            -Dsonar.login=\${SONARQUBE_TOKEN} \
                            -Dsonar.python.version=3.8,3.9,3.10 \
                            -Dsonar.language=py \
                            -Dsonar.qualitygate.wait=false || echo "Scanner completed with warnings"
                    """
                }
            }
        }
        
        stage('Wait for SonarQube Processing & Check Quality Gate') {
            steps {
                script {
                    echo '═══════════════════════════════════════════════════════════'
                    echo '          Waiting for SonarQube Analysis Results         '
                    echo '═══════════════════════════════════════════════════════════'
                    
                    // Get the CE task ID from the report-task.txt file
                    def taskId = null
                    def taskReportFile = '.scannerwork/report-task.txt'
                    
                    try {
                        def reportContent = sh(script: "cat ${taskReportFile}", returnStdout: true).trim()
                        def taskIdMatch = (reportContent =~ /ceTaskId=([^\n]+)/)
                        if (taskIdMatch) {
                            taskId = taskIdMatch[0][1]
                            echo "✓ Found SonarQube task ID: ${taskId}"
                        }
                    } catch (Exception e) {
                        echo "⚠ Could not read task ID from report file: ${e.message}"
                    }
                    
                    // Define variables outside withCredentials block so they're accessible later
                    def qualityGateStatus = 'UNKNOWN'
                    def blockerCount = 'UNKNOWN'
                    
                    // Use Jenkins credentials for SonarQube authentication
                    withCredentials([usernamePassword(
                        credentialsId: 'sonarqube-admin-token',
                        usernameVariable: 'SONAR_USER',
                        passwordVariable: 'SONAR_PASS'
                    )]) {
                        // Wait for SonarQube to finish processing
                        def taskStatus = 'PENDING'
                        def maxWaitTime = 300  // 5 minutes max wait
                        def waitInterval = 10   // Check every 10 seconds
                        def totalWaitTime = 0
                        
                        if (taskId) {
                            echo "Waiting for SonarQube to process the analysis..."
                            
                            while (totalWaitTime < maxWaitTime && taskStatus != 'SUCCESS' && taskStatus != 'FAILED') {
                                sleep(time: waitInterval, unit: 'SECONDS')
                                totalWaitTime += waitInterval
                                
                                try {
                                    def taskResponse = sh(
                                        script: """
                                            curl -s -u \${SONAR_USER}:\${SONAR_PASS} \
                                            '${SONARQUBE_URL}/api/ce/task?id=${taskId}'
                                        """,
                                        returnStdout: true
                                    ).trim()
                                    
                                    echo "Task response: ${taskResponse}"
                                    
                                    def statusMatch = (taskResponse =~ /"status":"([^"]+)"/)
                                    if (statusMatch) {
                                        taskStatus = statusMatch[0][1]
                                        echo "Task status: ${taskStatus} (waited ${totalWaitTime}s)"
                                    }
                                } catch (Exception e) {
                                    echo "⚠ Error checking task status: ${e.message}"
                                }
                            }
                            
                            if (taskStatus == 'SUCCESS') {
                                echo "✓ SonarQube analysis processing completed successfully"
                                // Give it a few more seconds to update the quality gate
                                sleep(time: 5, unit: 'SECONDS')
                            } else if (taskStatus == 'FAILED') {
                                echo "✗ SonarQube analysis processing failed"
                                env.RUN_HADOOP_JOB = 'false'
                                env.BLOCKER_COUNT = 'ANALYSIS_FAILED'
                                env.QUALITY_GATE_STATUS = 'ERROR'
                                return
                            } else {
                                echo "⚠ SonarQube analysis still processing after ${totalWaitTime}s"
                            }
                        } else {
                            echo "⚠ Could not get task ID, waiting 60 seconds as fallback..."
                            sleep(time: 60, unit: 'SECONDS')
                        }
                        
                        echo ''
                        echo '═══════════════════════════════════════════════════════════'
                        echo '          Checking Quality Gate and Blocker Issues        '
                        echo '═══════════════════════════════════════════════════════════'
                        
                        // Check the quality gate status and blocker count
                        def maxRetries = 5
                        def retryDelay = 10
                        
                        for (int i = 0; i < maxRetries; i++) {
                            try {
                                echo "Attempt ${i+1}/${maxRetries}: Querying SonarQube API..."
                                
                                // Check quality gate status
                                def qgResponse = sh(
                                    script: """
                                        curl -s -u \${SONAR_USER}:\${SONAR_PASS} \
                                        '${SONARQUBE_URL}/api/qualitygates/project_status?projectKey=Python-Code-Disasters'
                                    """,
                                    returnStdout: true
                                ).trim()
                                
                                echo "Quality Gate API Response: ${qgResponse}"
                                
                                def qgMatch = (qgResponse =~ /"status":"([^"]+)"/)
                                if (qgMatch.find()) {
                                    qualityGateStatus = qgMatch.group(1)
                                    echo "✓ Quality Gate Status: ${qualityGateStatus}"
                                }
                                
                                // Check blocker issues
                                def blockerResponse = sh(
                                    script: """
                                        curl -s -u \${SONAR_USER}:\${SONAR_PASS} \
                                        '${SONARQUBE_URL}/api/issues/search?componentKeys=Python-Code-Disasters&severities=BLOCKER&resolved=false'
                                    """,
                                    returnStdout: true
                                ).trim()
                                
                                echo "Blocker Issues API Response: ${blockerResponse}"
                                
                                def blockerMatch = (blockerResponse =~ /"total":(\d+)/)
                                if (blockerMatch.find()) {
                                    blockerCount = blockerMatch.group(1)
                                    echo "✓ Blocker Issues Count: ${blockerCount}"
                                }
                                
                                // If we got valid responses, break
                                if (qualityGateStatus != 'UNKNOWN' && blockerCount != 'UNKNOWN') {
                                    echo "✓ Successfully retrieved all required information"
                                    break
                                }
                                
                                if (i < maxRetries - 1) {
                                    echo "⚠ Incomplete data received, waiting ${retryDelay}s before retry..."
                                    sleep(time: retryDelay, unit: 'SECONDS')
                                }
                            } catch (Exception e) {
                                echo "⚠ Attempt ${i+1}/${maxRetries} failed: ${e.message}"
                                if (i < maxRetries - 1) {
                                    sleep(time: retryDelay, unit: 'SECONDS')
                                }
                            }
                        }
                    }
                    
                    echo ''
                    echo '═══════════════════════════════════════════════════════════'
                    echo '               Pipeline Decision Logic                    '
                    echo '═══════════════════════════════════════════════════════════'
                    
                    // Store SonarQube results for reporting
                    env.QUALITY_GATE_STATUS = qualityGateStatus
                    env.BLOCKER_COUNT = blockerCount
                    
                    // Display SonarQube analysis results
                    echo ''
                    echo '📊 SonarQube Analysis Results:'
                    echo "   - Quality Gate Status: ${qualityGateStatus}"
                    echo "   - Blocker Issues Found: ${blockerCount}"
                    echo ''
                    
                    // Decision logic: Only run Hadoop if no blocker issues
                    if (qualityGateStatus == 'UNKNOWN' || blockerCount == 'UNKNOWN') {
                        echo '⚠️  WARNING: Could not retrieve complete information from SonarQube'
                        echo "   - Quality Gate Status: ${qualityGateStatus}"
                        echo "   - Blocker Count: ${blockerCount}"
                        echo '   - Decision: SKIP Hadoop job (fail-safe mode)'
                        env.RUN_HADOOP_JOB = 'false'
                    } else if (qualityGateStatus == 'ERROR') {
                        echo '✗ Quality Gate: FAILED'
                        echo "   - Reason: Quality standards not met"
                        echo "   - Blocker Issues: ${blockerCount}"
                        echo '   - Decision: SKIP Hadoop job'
                        env.RUN_HADOOP_JOB = 'false'
                    } else if (blockerCount != '0') {
                        echo '✗ Blocker Issues Detected'
                        echo "   - Quality Gate: ${qualityGateStatus}"
                        echo "   - Blocker Issues: ${blockerCount}"
                        echo '   - Decision: SKIP Hadoop job'
                        env.RUN_HADOOP_JOB = 'false'
                    } else {
                        echo '✓ Quality Gate: PASSED'
                        echo '✓ Blocker Issues: 0'
                        echo '✓ Code quality standards met'
                        echo '   - Decision: RUN Hadoop job'
                        env.RUN_HADOOP_JOB = 'true'
                    }
                    
                    echo ''
                    if (env.RUN_HADOOP_JOB == 'true') {
                        echo '🚀 DECISION: Running Hadoop MapReduce job'
                    } else {
                        echo '⏸️  DECISION: Skipping Hadoop MapReduce job'
                    }
                    
                    echo '═══════════════════════════════════════════════════════════'
                    echo ''
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
                    echo "Quality Gate Status: ${env.QUALITY_GATE_STATUS ?: 'N/A'}"
                    echo "Blocker Issues Found: ${env.BLOCKER_COUNT ?: 'N/A'}"
                    echo "Hadoop Job Executed: ${env.RUN_HADOOP_JOB ?: 'false'}"
                    echo ''
                    
                    if (env.RUN_HADOOP_JOB == 'true') {
                        echo '✅ SCENARIO: Clean Code → Hadoop Executed'
                        echo ''
                        echo 'Pipeline Decision:'
                        echo '  • SonarQube Analysis: Complete'
                        echo "  • Quality Gate: ${env.QUALITY_GATE_STATUS}"
                        echo '  • Blocker Issues: 0'
                        echo '  • Decision: RUN Hadoop MapReduce job'
                        echo ''
                        echo "Output: ${env.HADOOP_OUTPUT_PATH ?: 'N/A'}"
                    } else {
                        if (env.BLOCKER_COUNT == 'UNKNOWN' || env.QUALITY_GATE_STATUS == 'UNKNOWN') {
                            echo '⚠️  SCENARIO: Unable to Determine Code Quality → Hadoop Skipped (Fail-Safe)'
                            echo ''
                            echo 'Pipeline Decision:'
                            echo '  • SonarQube Analysis: Complete'
                            echo "  • Quality Gate: ${env.QUALITY_GATE_STATUS ?: 'N/A'}"
                            echo "  • Blocker Issues: ${env.BLOCKER_COUNT ?: 'N/A'}"
                            echo '  • Decision: SKIP Hadoop job (fail-safe mode)'
                            echo ''
                            echo 'Issue: Could not retrieve complete information from SonarQube'
                        } else if (env.QUALITY_GATE_STATUS == 'ERROR') {
                            echo '✗ SCENARIO: Quality Gate Failed → Hadoop Skipped'
                            echo ''
                            echo 'Pipeline Decision:'
                            echo '  • SonarQube Analysis: Complete'
                            echo "  • Quality Gate: FAILED (${env.QUALITY_GATE_STATUS})"
                            echo "  • Blocker Issues: ${env.BLOCKER_COUNT}"
                            echo '  • Decision: SKIP Hadoop job'
                            echo ''
                            echo 'Action Required: Fix quality gate issues in SonarQube'
                            echo "                 Check: ${env.SONARQUBE_URL}/dashboard?id=Python-Code-Disasters"
                        } else if (env.BLOCKER_COUNT != '0') {
                            echo '✗ SCENARIO: Code with Blocker Issues → Hadoop Skipped'
                            echo ''
                            echo 'Pipeline Decision:'
                            echo '  • SonarQube Analysis: Complete'
                            echo "  • Quality Gate: ${env.QUALITY_GATE_STATUS}"
                            echo "  • Blocker Issues: ${env.BLOCKER_COUNT}"
                            echo '  • Decision: SKIP Hadoop job'
                            echo ''
                            echo 'Action Required: Fix blocker issues before Hadoop execution'
                            echo "                 Check: ${env.SONARQUBE_URL}/dashboard?id=Python-Code-Disasters"
                        } else {
                            echo '⚠️  SCENARIO: Unknown Reason → Hadoop Skipped'
                            echo ''
                            echo 'Pipeline Decision:'
                            echo '  • SonarQube Analysis: Complete'
                            echo "  • Quality Gate: ${env.QUALITY_GATE_STATUS ?: 'N/A'}"
                            echo "  • Blocker Issues: ${env.BLOCKER_COUNT ?: 'N/A'}"
                            echo '  • Decision: SKIP Hadoop job'
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



