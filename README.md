# AgriTrack Pro — Firebase Flutter POS

A Flutter source project for an agricultural supply store: email/password staff sign-in, product catalog and editing, stock adjustments, checkout with atomic Firestore transactions, sales history, operating expenses, and profit reporting.

## Firebase setup (required before running)
1. Install Flutter and Dart SDK; run `flutter doctor`.
2. Create a Firebase project at https://console.firebase.google.com and enable **Authentication → Email/Password** and **Cloud Firestore**.
3. In this folder run `flutter create .` to generate platform-specific Android/iOS files (these are not bundled).
4. Install Firebase CLI and FlutterFire CLI (`dart pub global activate flutterfire_cli`), log in, then run `flutterfire configure` for your Firebase project. This generates the platform configuration files. `main.dart` calls `Firebase.initializeApp()`; on **Android/iOS**, the generated native Firebase config supports this. For web, modify initialization to use `DefaultFirebaseOptions.currentPlatform` from generated `firebase_options.dart`.
5. Run `flutter pub get`.
6. Deploy security rules: `firebase deploy --only firestore:rules` from this folder (requires Firebase CLI login and project selection, e.g. `firebase use --add`).
7. In Firebase Authentication, manually create an owner account (email/password). Copy its UID and create `users/{uid}` in Firestore with fields `role: "owner"` and `active: true`. For staff, create their Auth user and `users/{uid}` with `role: "staff"` and `active: true`. Never expose a self-service role assignment in the client.
8. Run `flutter run` on a connected Android/iOS device or emulator.

## Project folders
- `lib/models` — typed product, sale, expense entities
- `lib/services` — Firestore streams and transactional checkout/stock logic
- `lib/views` — login, dashboard, inventory, POS, reports, expenses
- `lib/widgets` — common UI and currency formatting
- `lib/config` — Material 3 green theme
- `firestore.rules` — initial access-control rules

## Operational notes / limits
- **No real GCash or bank payment gateway is integrated.** The cashier records the method only after verifying external payment. This is not an automatic payment collection service.
- Sale prices and product costs are copied into each sale when checkout occurs; future product price changes do not rewrite historical gross profit.
- Checkout uses a Firestore transaction to update product stocks and save the sale atomically, preventing concurrent overselling when all writes use this app's transaction path.
- Firestore rules are a **starter baseline, not a fully tamper-proof accounting system**. A modified client with staff credentials could submit inconsistent sales or stock changes. For production, move checkout and stock adjustments to authenticated Firebase Cloud Functions with server-side price, quantity, role, payment and stock validation; block direct client writes to those collections.
- Reports load the most recent **500 sales and 500 expenses** and calculate net profit as revenue minus cost of goods sold minus recorded expenses. Older records are not included. Use server-side aggregates for a large business.
- This code was assembled without Flutter SDK in the execution environment; it has **not been compiled or tested on a device**. Run `flutter analyze`, test in the Firebase Emulator Suite, and fix any SDK/version-specific issues before deployment.
- Firestore may require indexes depending on future query changes; check console prompts.
- No product expiry/batch tracking, returns/refunds, offline conflict workflow, staff management UI, receipts PDF, or tax computation are implemented.
