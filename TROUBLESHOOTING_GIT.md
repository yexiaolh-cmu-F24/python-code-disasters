# Troubleshooting: No Repository URL Field

If you don't see a "Repository URL" field after selecting Git, try these steps:

## Option 1: Look for Additional Sections

After selecting "Git", scroll down on the page. The repository configuration might be in a separate section below. Look for:
- **"Repositories"** section
- **"Repository URL"** field
- **"Additional Behaviours"** section
- Any expandable sections (click to expand)

## Option 2: Install Git Plugin

The Git plugin might not be installed. To install it:

1. Go to: **Manage Jenkins** → **Plugins**
2. Click **"Available plugins"** tab
3. Search for: `Git`
4. Check **"Git plugin"**
5. Click **"Install without restart"**
6. Wait for installation (1-2 minutes)
7. Go back to configure your pipeline job

## Option 3: Use Pipeline Script Directly

If Git plugin installation is problematic, you can use the pipeline script directly:

1. Change **"Definition"** dropdown from **"Pipeline script from SCM"** to **"Pipeline script"**
2. Copy the contents of your `Jenkinsfile` from GitHub
3. Paste it into the script text area
4. Click **"Save"**

This bypasses the Git SCM configuration but still runs your pipeline.

## Option 4: Check Git Plugin Status

1. Go to: **Manage Jenkins** → **Configure System**
2. Scroll to **"Git"** section
3. Check if Git is configured there
4. If missing, the Git plugin might not be installed

## Quick Check: Is Git Plugin Installed?

Run this command to check:
```bash
curl -s 'http://136.114.99.232:8080/jenkins/pluginManager/api/json?tree=plugins[shortName,active]' | grep -i git
```

If no Git plugin is found, install it via the Plugin Manager.

