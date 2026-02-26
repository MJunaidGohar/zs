# ZS Assistant Chatbot - API Key Setup Guide

## Overview
This document provides instructions for configuring the Gemini API key for the ZS Assistant chatbot feature.

## Prerequisites
- Google AI Studio account (free)
- Android app package name and SHA-1 fingerprint

---

## Step 1: Get API Key from Google AI Studio

1. Visit [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key"
4. Select "Create API key in new project" (recommended)
5. Copy the generated API key

---

## Step 2: Secure the API Key

### Option A: Environment Variable (Recommended for Development)

Set the API key as an environment variable before running/building:

**Windows (PowerShell):**
```powershell
$env:GEMINI_API_KEY = "your-api-key-here"
flutter run
```

**Windows (CMD):**
```cmd
set GEMINI_API_KEY=your-api-key-here
flutter run
```

**Linux/Mac:**
```bash
export GEMINI_API_KEY=your-api-key-here
flutter run
```

### Option B: Dart Define (Recommended for Production Builds)

**Development:**
```bash
flutter run --dart-define=GEMINI_API_KEY=your-api-key-here
```

**Production Build:**
```bash
flutter build apk --dart-define=GEMINI_API_KEY=your-api-key-here
flutter build appbundle --dart-define=GEMINI_API_KEY=your-api-key-here
```

### Option C: CI/CD Pipeline (GitHub Actions, etc.)

Add to your workflow file:
```yaml
- name: Build APK
  run: flutter build apk --dart-define=GEMINI_API_KEY=${{ secrets.GEMINI_API_KEY }}
  env:
    GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
```

Store `GEMINI_API_KEY` in your repository secrets.

---

## Step 3: API Key Restrictions (Security)

**IMPORTANT:** Restrict your API key to prevent abuse:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to "APIs & Services" > "Credentials"
3. Find your API key and click "Edit"
4. Under "Application restrictions", select:
   - **Android apps**
   - Add your package name (e.g., `com.yourcompany.zarori_sawal`)
   - Add your SHA-1 fingerprint

### Get SHA-1 Fingerprint:

**Debug certificate:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

**Release certificate:**
```bash
keytool -list -v -keystore ~/path/to/your/release.keystore -alias your_alias
```

---

## Step 4: Verify Configuration

1. Run the app with API key configured
2. Navigate to any screen (Main, Learn, Test, Profile)
3. Tap the floating chat button (bottom-right)
4. Send a test message
5. Verify response from ZS Assistant

---

## API Usage Limits (Free Tier)

| Metric | Limit |
|--------|-------|
| Requests per day | 1,500 |
| Tokens per minute | 1,000,000 |
| Requests per minute | 15 |

The app implements a 15-message daily quota per user to stay within these limits.

---

## Troubleshooting

### Issue: "ZS Assistant is temporarily unavailable"
- **Cause:** API key not configured
- **Fix:** Follow Step 2 above

### Issue: "Service is busy. Please try again"
- **Cause:** Rate limit exceeded (15 requests/minute)
- **Fix:** Wait a moment and try again

### Issue: "Cannot answer that type of question"
- **Cause:** Content safety filter triggered
- **Fix:** Rephrase question to be more educational

### Issue: API key exposed in code
- **Fix:** Never hardcode API key. Use `--dart-define` or environment variables.

---

## Production Checklist

- [ ] API key restricted to Android app (package + SHA-1)
- [ ] Using `--dart-define` for production builds
- [ ] API key stored in CI/CD secrets (not in repository)
- [ ] Quota monitoring enabled in Google Cloud Console
- [ ] Alerts configured for unusual usage

---

## Security Best Practices

1. **Never commit API key to git repository**
2. **Rotate API key monthly**
3. **Monitor usage in Google Cloud Console**
4. **Set up billing alerts** (even on free tier)
5. **Restrict key to specific Android apps only**

---

## Additional Resources

- [Google AI Studio Documentation](https://ai.google.dev/gemini-api/docs)
- [Gemini API Pricing](https://ai.google.dev/pricing)
- [Flutter Environment Variables](https://dart.dev/guides/environment-declared-variables)

---

## Support

For issues or questions:
1. Check API key configuration
2. Verify network connectivity
3. Review app logs for error details
4. Check Google Cloud Console for quota usage
