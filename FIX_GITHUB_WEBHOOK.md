# Fix GitHub Webhook 403 Error

## The Problem

Your GitHub webhook is getting a **403 Forbidden** error:
```
Last delivery was not successful. Invalid HTTP Response: 403
```

This is because Jenkins CSRF protection is blocking the webhook request.

## The Solution

### Option 1: Use Correct Webhook URL (Recommended)

The webhook URL should **NOT** include `/jenkins` prefix:

**❌ Wrong:**
```
http://136.114.99.232:8080/jenkins/github-webhook/
```

**✅ Correct:**
```
http://136.114.99.232:8080/github-webhook/
```

The `/jenkins` prefix is only for the web UI, not for webhooks.

### Option 2: Configure GitHub Plugin Properly

If the GitHub plugin is installed, it should handle webhooks automatically. Check:

1. **Go to Jenkins:**
   - http://136.114.99.232:8080/jenkins

2. **Check GitHub Plugin:**
   - Manage Jenkins → Manage Plugins
   - Installed tab → Search for "GitHub"
   - Make sure "GitHub plugin" is installed

3. **Configure GitHub Plugin:**
   - Manage Jenkins → Configure System
   - Scroll to "GitHub" section
   - Add GitHub server if needed
   - Configure webhook settings

### Option 3: Disable CSRF for Webhook Endpoint (Not Recommended)

If you need to disable CSRF temporarily:

1. **Via Jenkins UI:**
   - Go to: http://136.114.99.232:8080/jenkins/configureSecurity
   - Uncheck "Enable CSRF protection"
   - Click "Save"
   - Test webhook
   - **Re-enable CSRF** after testing

2. **Via Script:**
   ```bash
   cd scripts
   ./disable-csrf-temporarily.sh
   # Test webhook
   ./re-enable-csrf.sh
   ```

## Steps to Fix

### 1. Update Webhook URL in GitHub

1. Go to your GitHub repository
2. Go to **Settings** → **Webhooks**
3. Click **Edit** on your webhook
4. Change **Payload URL** from:
   ```
   http://136.114.99.232:8080/jenkins/github-webhook/
   ```
   To:
   ```
   http://136.114.99.232:8080/github-webhook/
   ```
5. Click **"Update webhook"**

### 2. Test the Webhook

After updating, GitHub will automatically send a test payload. You should see:
- ✅ Green checkmark
- ✅ "Last delivery was successful"

### 3. Verify Jenkins Receives It

Check Jenkins build history - a new build should be triggered automatically when you push code.

## Alternative: Use Polling Instead

If webhooks continue to have issues, you can use polling:

1. **In Jenkins Job Configuration:**
   - Go to your pipeline job
   - Under "Build Triggers"
   - Check "Poll SCM"
   - Enter: `H/5 * * * *` (every 5 minutes)

This will check for changes every 5 minutes and trigger builds automatically.

## Verification

After fixing, test by:

1. **Make a small change:**
   ```bash
   echo "# Test" >> README.md
   git add README.md
   git commit -m "Test webhook"
   git push origin master
   ```

2. **Check Jenkins:**
   - Go to: http://136.114.99.232:8080/jenkins/job/python-code-analysis
   - A new build should appear automatically within seconds

3. **Check GitHub Webhook:**
   - Go to: GitHub → Settings → Webhooks
   - Click on your webhook
   - Check "Recent Deliveries"
   - Should show successful deliveries

## Summary

**Most Common Fix:**
- Change URL from `/jenkins/github-webhook/` to `/github-webhook/`
- Remove the `/jenkins` prefix

**If Still Not Working:**
- Verify GitHub plugin is installed
- Check Jenkins logs for errors
- Consider using polling as a fallback

