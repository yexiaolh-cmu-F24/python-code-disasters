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
        
        stage('SonarQube Analysis') {
            steps {
                script {
                    echo 'Running SonarQube analysis...'
                    
                    // Get the SonarQube Scanner tool
                    def scannerHome = tool 'SonarQube Scanner'
                    
                    // Run SonarQube scanner
                    withSonarQubeEnv('SonarQube') {
                    sh """
                        ${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=Python-Code-Disasters \
                            -Dsonar.sources=. \
                            -Dsonar.host.url=${SONARQUBE_URL} \
                            -Dsonar.python.version=3.8,3.9,3.10 \
                            -Dsonar.language=py
                    """
                    }
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                script {
                    echo 'Waiting for SonarQube Quality Gate...'
                    timeout(time: 5, unit: 'MINUTES') {
                        def qg = waitForQualityGate()
                        echo "Quality Gate status: ${qg.status}"
                        
                        // Store the quality gate result
                        env.QUALITY_GATE_STATUS = qg.status
                        
                        if (qg.status != 'OK') {
                            echo "WARNING: Quality gate failed with status: ${qg.status}"
                            // Don't fail the build, but mark for conditional execution
                            env.HAS_BLOCKER_ISSUES = 'true'
                        } else {
                            echo "SUCCESS: Quality gate passed!"
                            env.HAS_BLOCKER_ISSUES = 'false'
                        }
                    }
                }
            }
        }
        
        stage('Check for Blocker Issues') {
            steps {
                script {
                    echo 'Checking for blocker issues in SonarQube results...'
                    
                    def blockerCount = sh(
                        script: """
                            curl -s -u admin:admin \
                            '${SONARQUBE_URL}/api/issues/search?componentKeys=Python-Code-Disasters&severities=BLOCKER&resolved=false' \
                            | grep -o '"total":[0-9]*' | cut -d':' -f2 || echo '0'
                        """,
                        returnStdout: true
                    ).trim()
                    
                    echo "Blocker issues found: ${blockerCount}"
                    
                    if (blockerCount == '0') {
                        env.RUN_HADOOP_JOB = 'true'
                        echo '✓ No blocker issues found. Hadoop job will run.'
                    } else {
                        env.RUN_HADOOP_JOB = 'false'
                        echo "✗ Found ${blockerCount} blocker issue(s). Hadoop job will NOT run."
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
                        
                        # Upload to GCS
                        gsutil -m rm -rf ${REPO_GCS_PATH} || true
                        gsutil -m cp -r /tmp/repo-upload/* ${REPO_GCS_PATH}/
                        
                        echo "Code uploaded to ${REPO_GCS_PATH}"
                    """
                }
            }
        }
        
        stage('Run Hadoop MapReduce Job') {
            when {
                environment name: 'RUN_HADOOP_JOB', value: 'true'
            }
            steps {
                script {
                    echo 'Submitting Hadoop MapReduce job to count lines...'
                    
                    def timestamp = sh(script: 'date +%Y%m%d_%H%M%S', returnStdout: true).trim()
                    def outputPath = "gs://${OUTPUT_BUCKET}/results/${timestamp}"
                    
                    sh """
                        gcloud dataproc jobs submit pyspark \
                            gs://${STAGING_BUCKET}/jobs/line_counter_pyspark.py \
                            --cluster=${HADOOP_CLUSTER_NAME} \
                            --region=${HADOOP_REGION} \
                            --project=${GCP_PROJECT_ID} \
                            -- ${REPO_GCS_PATH} ${outputPath}
                    """
                    
                    env.HADOOP_OUTPUT_PATH = outputPath
                }
            }
        }
        
        stage('Display Results') {
            when {
                environment name: 'RUN_HADOOP_JOB', value: 'true'
            }
            steps {
                script {
                    echo 'Retrieving and displaying Hadoop job results...'
                    
                    sh """
                        echo "=================================="
                        echo "HADOOP MAPREDUCE JOB RESULTS"
                        echo "=================================="
                        echo ""
                        echo "Line counts for each file:"
                        echo ""
                        
                        # Download and display results
                        gsutil cat ${HADOOP_OUTPUT_PATH}/part-* || echo "No results found"
                        
                        echo ""
                        echo "=================================="
                        echo "Results also saved to: ${HADOOP_OUTPUT_PATH}"
                        echo "=================================="
                    """
                }
            }
        }
        
        stage('Results Summary') {
            steps {
                script {
                    echo '========================================='
                    echo 'PIPELINE EXECUTION SUMMARY'
                    echo '========================================='
                    echo "Quality Gate Status: ${env.QUALITY_GATE_STATUS}"
                    echo "Hadoop Job Executed: ${env.RUN_HADOOP_JOB}"
                    
                    if (env.RUN_HADOOP_JOB == 'true') {
                        echo "Results Location: ${env.HADOOP_OUTPUT_PATH}"
                    } else {
                        echo "Hadoop job was NOT executed due to blocker issues in code quality."
                    }
                    echo '========================================='
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


