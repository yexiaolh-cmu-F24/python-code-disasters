# Next Steps: Your Pipeline is Ready!

## ✅ Current Status

✅ **Jenkins pipeline job created:** `python-code-analysis`  
✅ **Job is accessible:** http://136.114.99.232:8080/jenkins/job/python-code-analysis

## Next Steps

### 1. Verify Pipeline Configuration

1. Click **"Configure"** on the job page
2. Check the **"Pipeline"** section:
   - Should be set to: **"Pipeline script from SCM"**
   - **SCM:** Git
   - **Repository URL:** `https://github.com/yexiaolh-cmu-F24/python-code-disasters`
   - **Script Path:** `Jenkinsfile`
   - **Branch:** `*/main` (or `*/master`)
3. Click **"Save"** if you made any changes

### 2. Configure SonarQube Connection (If Not Automated)

The SonarQube connection should be automatically configured via the init script, but verify:

1. Go to: **Manage Jenkins** → **Configure System**
2. Scroll to **"SonarQube servers"** section
3. Verify there's a server named **"SonarQube"** with URL: `http://130.211.231.208:9000`
4. If missing, add it:
   - Click **"Add SonarQube"**
   - Name: `SonarQube`
   - Server URL: `http://130.211.231.208:9000`
   - Server authentication token: (get from SonarQube UI)
   - Click **"Save"**

### 3. Test the Pipeline

1. On the job page, click **"Build Now"**
2. Watch the build progress in the **"Builds"** section
3. Click on the build number to see console output
4. The pipeline will:
   - Clone your GitHub repo
   - Run SonarQube analysis
   - Check for blocker issues
   - If no blockers, run Hadoop MapReduce job
   - Store results in GCS

### 4. View Results

After the pipeline runs successfully:

```bash
# View Hadoop job results
./scripts/view-results.sh

# Or use Python script for formatted output
python3 scripts/view-results.py
```

## Troubleshooting

- **Build fails?** Check the console output for errors
- **SonarQube connection fails?** Verify SonarQube is running and accessible
- **Hadoop job fails?** Check Dataproc cluster status and GCS permissions
- **No builds showing?** Click "Build Now" to trigger the first build

## Quick Links

- **Jenkins:** http://136.114.99.232:8080/jenkins
- **Pipeline Job:** http://136.114.99.232:8080/jenkins/job/python-code-analysis
- **SonarQube:** http://130.211.231.208:9000

