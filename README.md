# Archives App Setup Guide

This guide lists everything required to run the app locally with fewer setup errors.

## Prerequisites

- Flutter SDK (compatible with Dart SDK ^3.10.7)
- Dart SDK ^3.10.7
- Node.js 18.x (for Firebase Functions)
- npm (comes with Node.js)
- Firebase CLI

Install Firebase CLI:

```bash
npm install -g firebase-tools
```

Optional (recommended when using your own Firebase project):

```bash
dart pub global activate flutterfire_cli
```

## Flutter Dependencies (already used in this app)

- cupertino_icons: ^1.0.8
- firebase_core: ^3.13.0
- firebase_auth: ^5.5.2
- cloud_firestore: ^5.6.6
- flutter_riverpod: ^2.6.1
- go_router: ^14.8.1
- cached_network_image: ^3.4.1
- google_fonts: ^6.2.1
- intl: ^0.20.2
- timeago: ^3.7.0
- uuid: ^4.5.1
- shimmer: ^3.0.0
- image_picker: ^1.1.2
- http: ^1.2.2
- flutter_dotenv: ^6.0.0
- share_plus: ^10.1.4
- emoji_picker_flutter: ^4.4.0

Dev dependencies:

- flutter_lints: ^6.0.0
- flutter_native_splash: ^2.4.6
- fake_cloud_firestore: ^3.1.0

## Firebase Functions Dependencies

Inside functions/package.json:

- firebase-admin: ^11.8.0
- firebase-functions: ^4.3.1
- crypto: ^1.0.1

## Install Steps

Run these commands from the app root folder:

```bash
# 1) Install Flutter packages
flutter pub get

# 2) Install Firebase Functions packages
cd functions
npm install
cd ..

# 3) Run the app
flutter run
```

## Firebase Project Setup

This project already includes Firebase files such as:

- lib/firebase_options.dart
- android/app/google-services.json

If you want to use your own Firebase project, run:

```bash
flutterfire configure
```

Deploy Firestore rules and indexes:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## Important Billing Note

- Firestore/Auth usage can work on Spark in many cases.
- Cloud Functions deployment commonly requires Blaze billing.
- If you want a no-cost setup, skip Functions deployment.

## Troubleshooting

- If flutter pub get fails, check your Flutter and Dart versions.
- If firebase deploy fails, verify Firebase login and project selection:

```bash
firebase login
firebase use <your-project-id>
```

- If Android build fails, confirm Android SDK and local.properties are configured.

## Quick Run Checklist

- .env file exists in project root (required by flutter_dotenv)
- Firebase project is configured
- flutter pub get completed
- npm install completed in functions folder
- flutter run works
