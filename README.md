<div align="center">
  <img
    src="assets/images/StudySync.png"
    width="100"
    height="100"
    style="border-radius: 20%;"
    alt="StudySync Logo"
  />
  <h1 style="margin: 12px 0 0 0;">StudySync — Study Management Mobile App </h1>

  <br />
  <br />

  <p>
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT" /></a>
    <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-%2302569B.svg?logo=flutter&logoColor=white" alt="Flutter" /></a>
    <a href="https://dart.dev/"><img src="https://img.shields.io/badge/Dart-%230175C2.svg?logo=dart&logoColor=white" alt="Dart" /></a>
    <a href="https://firebase.google.com/"><img src="https://img.shields.io/badge/Firebase-039BE5?logo=Firebase&logoColor=white" alt="Firebase" /></a>
    <a href="https://www.android.com/"><img src="https://img.shields.io/badge/Android-3DDC84?logo=android&logoColor=white" alt="Android" /></a>
  </p>
</div>

## 📘 About The Project

**StudySync** is a privacy-focused study helper that lets students create and manage study subjects, save notes, track progress, and use an optional on-device AI assistant for emotional support and study tips. The app is designed to work fully offline by default and offers optional cloud sync for convenience.

This Project was done by:

- **Zoubeir Hicheri**
- **Sadok Khelil**
- **Zoubair Garma**

from the INDP2-E Group.

### 🛠️ Built With

* ![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
* ![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
* ![Firebase](https://img.shields.io/badge/firebase-%23039BE5.svg?style=for-the-badge&logo=firebase)
* ![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
* ![Llama](https://img.shields.io/badge/AI-Llama-blueviolet?style=for-the-badge)
* ![SQLite](https://img.shields.io/badge/sqlite-%2307405e.svg?style=for-the-badge&logo=sqlite&logoColor=white)

---

## 📱 Frontend Preview (UI)

The UI features a clean, student-focused design including a Dashboard, Subject Management, Social features, and an AI Chat interface.

<div align="center">
  <table>
    <tr>
      <td align="center">
        <img src="![Image](https://github.com/user-attachments/assets/2e744888-db42-4d1b-9f59-ba33da814b51)" width="200" alt="Home Screen" />
        <br />
        <sub><b>Home Dashboard</b></sub>
      </td>
      <td align="center">
        <img src="YOUR_IMAGE_LINK_HERE" width="200" alt="Chat Screen" />
        <br />
        <sub><b>AI Support Chat</b></sub>
      </td>
      <td align="center">
        <img src="YOUR_IMAGE_LINK_HERE" width="200" alt="Subjects Screen" />
        <br />
        <sub><b>Subject Manager</b></sub>
      </td>
       <td align="center">
        <img src="YOUR_IMAGE_LINK_HERE" width="200" alt="Timer Screen" />
        <br />
        <sub><b>Study Timer</b></sub>
      </td>
    </tr>
  </table>
</div>

---

## 🧩 Features

### User Accounts (Email & Google)
Secure sign-in options so students can use the app with familiar credentials. Sessions persist so users don't need to sign in every time.

### Subject CRUD
Quickly add a subject with a title, description, and progress indicator. Edit notes and progress at any time and remove subjects when finished. All changes are saved locally immediately for a responsive experience.

### Offline-First Storage
The app stores all content on the device so it remains usable without network access. Edits are immediate and persist across app restarts, making it reliable in low-connectivity environments.

### Optional Background Sync
When enabled, local changes are synchronized to a cloud backend in the background so the user's data can be backed up and shared between devices without interrupting their workflow.

### On-Device AI Assistant
An optional, local AI provides empathetic responses and concise study suggestions. The assistant runs on-device so user conversations do not leave the phone, protecting privacy.

### Model Downloading
The app can download a pretrained model from the project's Kaggle dataset onto the device for offline inference. If direct download is not possible, the model can be transferred to the device manually.

---

## 🛠️ Tech Stack

- **Framework:** Flutter (Dart)
- **Local Database:** SQFlite (Offline persistence)
- **Backend Services:** Firebase Auth, Firestore (Optional Sync)
- **AI Engine:** Llama via `llama_flutter` (On-device inference)

---

## 📂 Project Structure

```text
MY_APP/
├── .dart_tool/
├── android/
├── assets/
│   ├── fonts/
│   └── images/
│       ├── Arrow - Left.png
│       ├── cat.png
│       ├── google_Logo.png
│       ├── StudySync.png
│       └── StudySync2.png
├── build/
├── ios/
├── lib/
│   ├── models/
│   │   ├── study_session_model.dart
│   │   ├── subject_model.dart
│   │   └── subject_model.g.dart
│   ├── screens/
│   │   ├── add_subject.dart
│   │   ├── calendar_screen.dart
│   │   ├── friends_request_screen.dart
│   │   ├── friends_screen.dart
│   │   ├── home.dart
│   │   ├── incoming_sessions_screen.dart
│   │   ├── model_download_page.dart
│   │   ├── signin_screen.dart
│   │   ├── signup_screen.dart
│   │   ├── Splash.dart
│   │   ├── subject_list_screen.dart
│   │   ├── support_chat_screen.dart
│   │   ├── timer_session_screen.dart
│   │   ├── update_subject.dart
│   │   └── user_settings_screen.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── friends_service.dart
│   │   ├── llm_chat_service.dart
│   │   ├── llm_download_service.dart
│   │   ├── mock_llm_chat_service.dart
│   │   ├── session_service.dart
│   │   └── subject_service.dart
│   ├── widgets/
│   │   ├── background.dart
│   │   ├── base_screen.dart
│   │   ├── bottom_nav_with_fab.dart
│   │   ├── Custom_Button.dart
│   │   ├── custom_text_field.dart
│   │   ├── nav_components.dart
│   │   ├── notification_icon.dart
│   │   └── subject_card.dart
│   ├── firebase_options.dart
│   └── main.dart
├── linux/
├── macos/
├── test/
│   └── widget_test.dart
├── web/
├── windows/
├── .flutter-plugins-dependencies
├── .gitignore
├── .metadata
├── analysis_options.yaml
├── firebase.json
├── firestore.indexes.json
├── firestore.rules
├── flutter_01.png

````


# 🚀 Getting Started

## Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (Latest Stable)
```bash
  flutter --version
```
- **Android Studio** or **VS Code** with Flutter extensions.
- **Android Device** or **Emulator** (API 26+ recommended for AI features).

## Installation

### Clone the repository
```bash
git clone https://github.com/YOUR_USERNAME/StudySync.git
cd StudySync
```

### Install Dependencies
```bash
flutter pub get
```

### Setup Firebase
- Place your `google-services.json` file in `android/app/`.

### Run the App
1. Connect your device via USB.
2. Run the following command:
```bash
flutter run
```

## 💻 Commands

- `flutter run` - Run the app on the connected device.
- `flutter build apk --release` - Build a release APK for Android.
- `flutter build apk --split-per-abi` - Build optimized APKs for specific architectures.
- `flutter clean` - Clear build cache.
├── pubspec.lock
├── pubspec.yaml
└── README.md
