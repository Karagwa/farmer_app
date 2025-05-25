# CI/CD Pipeline Documentation

This document describes the Continuous Integration and Continuous Deployment (CI/CD) pipeline for the HPGM app.

## Overview

Our CI/CD pipeline automates the process of testing, building, and deploying the application to ensure consistent quality and rapid delivery.

## Pipeline Stages

┌───────────────┐      ┌───────────────┐      ┌────────────────┐
│               │      │               │      │                │
│  Code Change  ├─────►│  CI Pipeline  ├─────►│  CD Pipeline   │
│               │      │               │      │                │
└───────────────┘      └───────┬───────┘      └────────┬───────┘
                               │                       │
                               ▼                       ▼
                       ┌───────────────┐      ┌────────────────┐
                       │               │      │                │
                       │    Tests      │      │  Distribution  │
                       │               │      │                │
                       └───────────────┘      └────────────────┘

1. **Analyze and Test**
   - Static code analysis to catch potential issues
   - Unit tests to verify functionality
   - Widget tests to verify UI components

2. **Build**
   - Android APK generation
   - iOS build preparation

3. **Deploy**
   - Firebase App Distribution for testing
   - Google Play Store deployment for production

## Workflow Triggers

- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Manual trigger via GitHub Actions UI

## Release Process

1. Create a release using the "Create Release" workflow
2. Select release type (major, minor, patch)
3. Automated version bump, tagging, and release creation
4. Build and deploy automatically based on the new tag

## Required Secrets

- `FIREBASE_ANDROID_APP_ID`: Firebase Android app ID
- `FIREBASE_SERVICE_ACCOUNT_JSON`: Firebase service account JSON
- `PLAY_STORE_UPLOAD_KEY`: Google Play Store upload key
- `RELEASE_PAT`: GitHub Personal Access Token with repository permissions

## Local Development

When developing locally, use the following commands to run tests:

```bash
# Run unit tests
flutter test test/unit/

# Run widget tests
flutter test test/widget/

# Run a specific test file
flutter test test/unit/app_utils_test.dart
```

## Practical Next Steps

1. **Repository Setup:**
   - Initialize a Git repository (if not already done)
   - Push your code to GitHub
   - Set up the GitHub repository secrets

2. **Firebase Setup:**
   - Create a Firebase project
   - Register your Android and iOS apps
   - Generate a service account key for deployment

3. **Google Play Setup:**
   - Create a Google Play developer account
   - Create an application listing
   - Set up release tracks (internal, alpha, beta, production)

## Conclusion

This CI/CD pipeline will provide:

1. Automated testing to catch bugs early
2. Consistent build processes
3. Automated deployment to testing and production channels
4. Proper versioning and release management
5. Comprehensive documentation for the team

