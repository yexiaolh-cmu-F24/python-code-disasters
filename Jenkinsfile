pipeline {
  agent any
  options { timestamps() }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('SonarQube Analysis') {
      steps {
        sh '''
          set -eux
          SCAN_VERSION="5.0.1.3006"
          ZIP_FILE="sonar-scanner-cli-${SCAN_VERSION}-linux-x64.zip"
          SCAN_DIR="sonar-scanner-${SCAN_VERSION}-linux-x64"
          BASE_URL="https://binaries.sonarsource.com/Distribution/sonar-scanner-cli"
          curl -fsSL -o "${ZIP_FILE}" "${BASE_URL}/${ZIP_FILE}"
          rm -rf "${DIR_NAME}" || true
          jar xf "${ZIP_FILE}"
          "./${DIR_NAME}/bin/sonar-scanner" \
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
