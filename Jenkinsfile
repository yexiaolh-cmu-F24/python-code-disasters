pipeline {
  agent any
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('SonarQube Analysis (CLI)') {
        steps {
            script {
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
                      -Dsonar.projectKey=python-code-disasters \
                      -Dsonar.sources=. \
                      -Dsonar.host.url=\${SONARQUBE_URL} \
                      -Dsonar.login=\${SONAR_TOKEN} \
                      -Dsonar.python.version=3
                """
            }
        }
    }

    stage('Quality Gate (manual check for Week-6)') {
      steps {
        echo "Open $SONARQUBE_URL to view analysis and Quality Gate."
      }
    }
  }
}
