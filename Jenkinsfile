pipeline {
  agent any
  options { timestamps() }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('SonarQube Analysis') {
      steps {
        sh '''
          set -euxo pipefail
          SCAN_VERSION="5.0.1.3006"
          curl -sL -o scanner.zip https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SCAN_VERSION}-linux-x64.zip
          unzip -q scanner.zip
          ./sonar-scanner-${SCAN_VERSION}-linux-x64/bin/sonar-scanner \
            -Dsonar.host.url="$SONAR_HOST_URL" \
            -Dsonar.login="$SONAR_TOKEN" \
            -Dsonar.projectKey="python-code-disasters" \
            -Dsonar.projectName="python-code-disasters" \
            -Dsonar.sources=. \
            -Dsonar.python.version=3.11
        '''
      }
    }
    stage('Quality Gate (manual check for Week-6)') {
      steps { echo "Open $SONAR_HOST_URL to view analysis and Quality Gate." }
    }
  }
}
