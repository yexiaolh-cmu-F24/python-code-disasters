pipeline {
  agent any
  options { timestamps() }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('SonarQube Analysis') {
      steps {
        sh '''
          set -eux
          VER="5.0.1.3006"
          ZIP="sonar-scanner-cli-${VER}-linux-x64.zip"
          DIR="sonar-scanner-${VER}-linux-x64"

          URL1="https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/${ZIP}"
          URL2="https://repo1.maven.org/maven2/org/sonarsource/scanner/cli/sonar-scanner-cli/${VER}/${ZIP}"

          curl -fsSL -A "curl/7.x Jenkins" -o "${ZIP}" "${URL1}" || \
          curl -fsSL -A "curl/7.x Jenkins" -o "${ZIP}" "${URL2}"

          rm -rf "${DIR}" || true
          jar xf "${ZIP}"
          "./${DIR}/bin/sonar-scanner" \
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
