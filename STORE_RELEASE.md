# Releasing RewireMind

The app keeps everything on the phone and has no login, so there is no server,
no account system and nothing to delete remotely. That keeps both store
reviews simple.

## Before either store

- **Privacy policy URL.** Both stores require one. The app links to
  `https://rewired.app/privacy` and `/terms` (set in `lib/content/app_links.dart`).
  Those pages must exist before you submit. The honest summary is short: the
  app collects no personal data, stores everything on the device, and has no
  analytics or ads.
- **Feedback email.** `hello@rewired.app` must be a real inbox, or change it in
  `lib/content/app_links.dart`.
- **Version.** Bump `version:` in `pubspec.yaml` for every upload
  (`1.0.0+1` → `1.0.1+2`). The number after `+` must always go up.

## Android (Google Play)

1. **Create your upload key, once.** Keep the file and passwords safe. If you
   lose them you cannot update the app.

   ```
   keytool -genkey -v -keystore %USERPROFILE%\rewiremind-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. **Point the build at it.** Create `android/key.properties` (it is ignored by
   git — never commit it):

   ```
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=upload
   storeFile=C:/Users/paras/rewiremind-upload.jks
   ```

   Without this file, release builds still work but are signed with the debug
   key, which Play rejects.

3. **Build the bundle** (review tools stay off):

   ```
   flutter build appbundle --release
   ```

   Upload `build/app/outputs/bundle/release/app-release.aab`.

4. **In Play Console** (one-time $25 developer account): create the app, fill in
   the listing, add the privacy policy URL, answer *Data safety* with "no data
   collected or shared", complete the content rating, then upload the bundle to
   internal testing first.

## iOS (App Store)

This needs a **Mac with Xcode** and an **Apple Developer account** ($99/year).
It cannot be built or tested from Windows.

1. On the Mac: `flutter pub get`, then open `ios/Runner.xcworkspace` in Xcode.
2. *Runner → Signing & Capabilities*: choose your Team. The bundle id is
   `com.parasjain.rewiremind`.
3. Add a privacy manifest: *File → New → File → App Privacy*, name it
   `PrivacyInfo`, add it to the Runner target, and declare **User Defaults**
   with reason **CA92.1** (the app stores its data with it). Leave tracking off
   and data collected empty.
4. Build and upload:

   ```
   flutter build ipa --release
   ```

   Then upload with Xcode's Organizer or the Transporter app.
5. **In App Store Connect**: create the app, fill in the listing and privacy
   policy URL, set *App Privacy* to "Data Not Collected", add screenshots, and
   submit.

Already done in the project: the home screen name reads RewireMind, the photo
picker has its permission messages, and the export-compliance question is
answered (no custom encryption). The home screen widget is Android-only, so the
screens offering it are hidden on iPhone.

## App icon

Every icon is built from one image by `tool/make_icons.py`:

```
python tool/make_icons.py C:/Users/paras/Downloads/rewired_mind.png
```

It writes the iPhone icon set, the Android launcher icons (including the
layered and themed versions), the app's own copy, and the two store uploads:

- `store/app_store_icon_1024.png` — App Store Connect (1024×1024, no transparency)
- `store/play_store_icon_512.png` — Play Console listing (512×512)

The source is only 398 pixels square, so the large sizes are enlarged from it.
A 1024-pixel original would give sharper store icons; rerun the script with it.

## Review tools

Demo data, "Stand on day 2" and the notification test panel only exist in
builds made with `--dart-define=DEV_TOOLS=true`. Store builds made with the
commands above never include them.
