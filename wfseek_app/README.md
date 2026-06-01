# wfseek_app

A distributed arbitrage scanning network for Nigerian bookmakers.

Every user's phone becomes a node that scrapes odds from 30 bookmakers using
reverse-engineered public APIs, detects arbitrage opportunities, and syncs
them to Firebase Realtime Database so all users see the results.

## Stack

- **Flutter** (Dart) mobile app
- **Firebase** Auth + Realtime Database
- **Workmanager** for periodic background scans
- **WebView** for stealth cookie / User-Agent harvesting
- **TFLite** for team-name semantic matching
- **Telegram bot** (Vercel serverless) for activation-code generation

## Project layout

```
wfseek_app/
  lib/
    main.dart
    screens/         # UI
    services/        # Auth, cookies, scanning, matching, arb detection
    scrapers/        # 30 bookmaker scrapers + registry + base + config
  assets/
    model.tflite     # produced by CI from convert_model.py
  convert_model.py
  .github/workflows/build-apk.yml
  telegram-bot/      # Vercel serverless bot
  firebase.rules.json
```

## Building locally

```bash
flutter pub get
python convert_model.py   # generates assets/model.tflite
flutter build apk --debug
```

## CI

Push to `main` (or run the workflow manually) and download the artifact
`wfseek-debug-apk` from the GitHub Actions run.

## Firebase rules

Apply `firebase.rules.json` to your Realtime Database.

## Bookmakers

30 bookmakers configured in `lib/scrapers/config.dart`. The bodies of each
scraper's `getOdds()` are intentionally left as `TODO` placeholders that
return `[]`. Replace them with real parsers as you reverse-engineer each
site's public API.

## Notes

- The app **forces** the user to disable battery optimization before reaching
  the home screen (Android).
- All **protected** bookmaker cookies must be harvested via WebView before
  the home screen is shown (first-time verification flow).
- Manual scans overwrite the global `opportunities` node — last writer wins.
- Up to 100 simultaneous clients receive opportunities over websocket; the
  rest fall back to 12-second polling.
