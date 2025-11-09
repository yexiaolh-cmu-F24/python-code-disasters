# Manual Pipeline Setup Guide

## Step 1: Install Pipeline Plugin

1. Go to: **http://136.114.99.232:8080/jenkins/pluginManager/available**
2. In the search box (top right), type: `Pipeline`
3. Find **"Pipeline"** or **"Workflow Aggregator"** in the results
4. Check the box next to it
5. Scroll down and click **"Install without restart"**
6. Wait 1-2 minutes for installation

## Step 2: Install Additional Plugins (Recommended)

While you're there, also install:
- **Git** plugin (for GitHub integration)
- **GitHub** plugin (for webhooks)
- **SonarQube Scanner** plugin (search for "SonarQube")

Click "Install without restart" after selecting them.

## Step 3: Create Pipeline Job

1. Go to: **http://136.114.99.232:8080/jenkins**
2. Click **"New Item"** (or "Create a job")
3. Enter a name: `python-code-analysis` (or any name you prefer)
4. Select **"Pipeline"** (should be visible now)
5. Click **"OK"**

## Step 4: Configure Pipeline Job

1. **Pipeline Definition:**
   - Select: **"Pipeline script from SCM"**
   
2. **SCM:**
   - Select: **"Git"**
   
3. **Repository URL:**
   - Enter your GitHub repo URL (from `terraform.tfvars` or your repo)
   - Example: `https://github.com/yourusername/python-code-disasters.git`
   
4. **Credentials:**
   - If it's a public repo, leave blank
   - If it's private, you'll need to add GitHub credentials
   
5. **Branches to build:**
   - Branch Specifier: `*/main` or `*/master` (depending on your default branch)
   
6. **Script Path:**
   - Enter: `Jenkinsfile`
   
7. Click **"Save"**

## Step 5: Configure SonarQube Server (if not automated)

1. Go to: **Manage Jenkins** → **Configure System**
2. Scroll to **"SonarQube servers"** section
3. Click **"Add SonarQube"**
4. **Name:** `SonarQube`
5. **Server URL:** `http://130.211.231.208:9000` (your SonarQube IP)
6. **Server authentication token:** 
   - Click **"Add"** → **"Jenkins"**
   - **Kind:** Secret text
   - **Secret:** (paste your SonarQube token - get it from SonarQube UI)
   - **ID:** `sonarqube-token`
   - Click **"Add"**
   - Select the token from dropdown
7. Click **"Save"**

## Step 6: Test the Pipeline

1. Go to your pipeline job page
2. Click **"Build Now"**
3. Watch the build progress
4. Check the console output for any errors

## Quick Reference URLs

- **Jenkins:** http://136.114.99.232:8080/jenkins
- **SonarQube:** http://130.211.231.208:9000
- **Plugin Manager:** http://136.114.99.232:8080/jenkins/pluginManager/available

## Troubleshooting

- **"Pipeline" option not showing?** → Make sure Pipeline plugin is installed and Jenkins is restarted
- **Can't connect to SonarQube?** → Check the SonarQube URL and token
- **Git clone fails?** → Verify repository URL and branch name

