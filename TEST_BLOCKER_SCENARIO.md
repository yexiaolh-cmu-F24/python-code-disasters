# Testing Blocker Issues Scenario

## What We're Testing

This test verifies that the Jenkins pipeline correctly:
1. Detects blocker-level issues in SonarQube
2. Skips the Hadoop MapReduce job when blockers are found
3. Provides clear feedback about why the job was skipped

## Test File Created

**File:** `test_blocker_issues.py`

This file contains **10 blocker-level security vulnerabilities** that SonarQube will detect:

1. **Hardcoded credentials** - `PASSWORD = "admin123"` and `API_KEY = "sk_live_..."` 
2. **SQL injection vulnerability** - Unescaped user input in SQL query
3. **Command injection vulnerability** - `os.system()` and `subprocess.call()` with user input
4. **Code injection** - Dangerous use of `eval()`
5. **Hardcoded cryptographic key** - Secret key in source code
6. **Insecure random** - Using `random.randint()` for security tokens
7. **Deserialization vulnerability** - Unpickling untrusted data
8. **Missing input validation** - File operations without validation
9. **Hardcoded IP address** - Should be configurable
10. **Insecure hashing** - Using MD5 for passwords

## Expected Behavior

When the pipeline runs:

1. ✅ **Checkout** - Code is checked out from GitHub
2. ✅ **SonarQube Analysis** - Scanner runs and uploads results
3. ✅ **Wait for Processing** - Pipeline waits for SonarQube to process
4. ✅ **Check Quality Gate** - Queries SonarQube API for blocker count
5. ✅ **Detect Blockers** - Should find multiple blocker issues
6. ✅ **Skip Hadoop Job** - Hadoop job should be **SKIPPED** because blockers > 0
7. ✅ **Display Results** - Clear message explaining why job was skipped

## How to Trigger the Test

### Option 1: Automatic (if webhook configured)
The build should trigger automatically when code is pushed to GitHub.

### Option 2: Manual Trigger
1. Go to: http://136.114.99.232:8080/jenkins/job/python-code-analysis
2. Click **"Build Now"**

## What to Look For

In the build console output, you should see:

```
📊 SonarQube Analysis Results:
   - Quality Gate Status: OK (or ERROR)
   - Blocker Issues Found: [number > 0]

✗ Blocker Issues Detected
   - Count: [number]
   - Decision: SKIP Hadoop job
```

And then:

```
Stage "Upload Code to GCS" skipped due to when conditional
Stage "Execute Hadoop MapReduce Job" skipped due to when conditional
Stage "Display Hadoop Results" skipped due to when conditional
```

## Verification Steps

1. **Check Build Status:**
   ```bash
   curl -s 'http://136.114.99.232:8080/jenkins/job/python-code-analysis/lastBuild/api/json?tree=result' | python3 -m json.tool
   ```

2. **View Build Console:**
   - Go to: http://136.114.99.232:8080/jenkins/job/python-code-analysis
   - Click on the latest build
   - Review the console output

3. **Check SonarQube Dashboard:**
   - Go to: http://130.211.231.208:9000 (or use port forwarding)
   - Login: admin / admin
   - Navigate to project: **Python-Code-Disasters**
   - Check the Issues tab - should show multiple blocker issues

4. **Verify Hadoop Job Was Skipped:**
   - Check that no new results appear in GCS
   - Check build console for "skipped due to when conditional" messages

## Success Criteria

✅ Pipeline detects blocker issues  
✅ Blocker count > 0  
✅ Hadoop job is skipped  
✅ Clear messaging about why job was skipped  
✅ Build completes successfully (even though Hadoop was skipped)

## Next Test: Fix Blockers

After verifying this works, you can:
1. Remove or fix the blocker issues in `test_blocker_issues.py`
2. Push the fix
3. Verify that Hadoop job **runs** when blockers = 0

## Troubleshooting

If blockers are not detected:
1. Check SonarQube scanner logs in build console
2. Verify SonarQube project exists and is accessible
3. Check that the file is being scanned (check `sonar.sources` in Jenkinsfile)
4. Wait longer - SonarQube may need time to process results

If Hadoop job still runs:
1. Check the blocker count in build console
2. Verify the decision logic in Jenkinsfile (line ~349)
3. Check that `env.RUN_HADOOP_JOB` is set to 'false'

