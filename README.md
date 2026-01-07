# StudySync — Features & Install Guide 📚🔒

**Short description:** StudySync helps students create and manage study subjects, save notes, and track progress. The app is built with privacy and portability in mind — all core features and an optional AI assistant can run entirely on-device (no external LLM calls required).

---

## Key Features

- **User auth:** Email/password and Google Sign-In
- **Subject management:** Create, edit, delete subjects; attach notes and progress indicators
- **Offline-first:** Local persistence using **Hive** so the app fully works without network
- **Background sync (optional):** Syncs local changes to **Cloud Firestore** when online (Android WorkManager)
- **Local AI assistant (emotional support):** A local AI model is available to install and run on-device for private, offline emotional support and study tips
- **Model downloads (Dio):** The app uses **Dio** primarily to download the local AI model into on-device storage so the assistant can run fully offline for privacy and portability
- **Privacy & portability:** All data and AI processing can remain on-device for maximum user privacy and easy portability between devices

---

## Local AI Model — Quick Notes

- A **local AI model** (pretrained) for emotional support and study help is available in the project's **Kaggle** repository and can be installed on-device for private, offline use.
- For quick demos or grading, the repo also includes a mock LLM (`lib/services/mock_llm_chat_service.dart`) that allows the chat UI to work on an emulator.
- Install the real model (step-by-step):
  1. **Test on a physical device.** Local model downloads and runtime are device-dependent.
  2. Open **Settings** in the app and press **Download AI Assistant**. The in-app downloader (Dio) will fetch the model from the project's Kaggle repo (ensure the dataset is public or the download URL is reachable).
  3. Wait for download completion; the model will be saved to the app's local storage (e.g., `assets/models/local_ai/` or the app data folder).


Note: After installation the model runs offline

## Install & Run (minimal, exact steps)

Prerequisites:
- Flutter SDK (Dart >= 3.10)
- Android Studio or Xcode (for device/emulator builds)

Commands:
- Clone: `git clone <repo-url>` and `cd <project-root>`
- Install deps: `flutter pub get`
- Generate code (Hive adapters, etc.):
  `flutter pub run build_runner build --delete-conflicting-outputs`
- Run: `flutter run -d <device>`

