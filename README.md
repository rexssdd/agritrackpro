# AgriTrack Pro — Firebase Flutter POS

A Flutter source project for an agricultural supply store: email/password staff sign-in, product catalog and editing, stock adjustments, checkout with atomic Firestore transactions, sales history, operating expenses, and profit reporting.

## Firebase setup (required before running)
1. Install Flutter and Dart SDK; run `flutter doctor`.
2. Create a Firebase project at https://console.firebase.google.com and enable **Authentication → Email/Password** and **Cloud Firestore**.
3. In this folder run `flutter create .` to generate platform-specific Android/iOS files (these are not bundled).
4. Install Firebase CLI and FlutterFire CLI (`dart pub global activate flutterfire_cli`), log in, then run `flutterfire configure` for your Firebase project. This generates the platform configuration files. `main.dart` calls `Firebase.initializeApp()`; on **Android/iOS**, the generated native Firebase config supports this. For web, modify initialization to use `DefaultFirebaseOptions.currentPlatform` from generated `firebase_options.dart`.
5. Run `flutter pub get`.
6. Install the backend dependencies with `npm.cmd --prefix functions ci`, then deploy the functions and rules together with `firebase.cmd deploy --only functions,firestore:rules --project agritrackpro-73030`. See [backend deployment](functions/README.md) for billing/runtime requirements and existing-store migration.
7. In Firebase Authentication, manually create an owner account (email/password). Copy its UID and create `users/{uid}` in Firestore with fields `role: "owner"` and `active: true`. For staff, create their Auth user and `users/{uid}` with `role: "staff"` and `active: true`. Never expose a self-service role assignment in the client.
8. Run `flutter run` on a connected Android/iOS device or emulator.

## Registration and Google sign-in

The authentication screen supports email/password registration and Google sign-in.
New accounts receive a pending `users/{authUid}` profile with `role: "staff"`
and `active: false` on their first app sign-in. Owners approve or disable access
from the Accounts tab and can send password reset emails. Passwords are never
displayed or changed directly by the owner. Disabled access blocks store data;
it does not disable the Firebase Authentication login account. Existing accounts
sync their email when they next sign in. Bootstrap the first owner manually in
Firestore with `role: "owner"` and `active: true`; users cannot assign their own roles.
Deploy the updated rules to enable pending profiles and owner account management:

```powershell
firebase.cmd deploy --only functions,firestore:rules --project agritrackpro-73030
```

Enable Email/Password and Google in Firebase Console > Authentication > Sign-in
method, and choose a project support email for Google. For Android, run
`./gradlew.bat signingReport` from the `android` directory. Add the debug SHA-1
and SHA-256 fingerprints to the Firebase Android app settings. Add release or
Play App Signing fingerprints before distributing the app.

Download the updated Android configuration from Firebase into
`android/app/google-services.json`. It must include a web OAuth client entry
(`client_type: 3`). Rerun `dart pub global run flutterfire_cli:flutterfire configure`
after enabling Google, then fully stop and rebuild the app. Hot reload cannot
install a new native plugin. Enable Windows Developer Mode if Flutter reports
that plugin symlinks are unavailable, and rerun `flutter pub get`.

For iOS/macOS, complete the Google Sign-In URL scheme and client ID setup in
the [plugin documentation](https://pub.dev/packages/google_sign_in_ios).
Web uses Firebase's Google popup flow; configure authorized domains in Firebase.

## Project folders

Active owners see a dedicated Owner console with Overview, Products, Sales,
and Accounts tabs. Reports and Expenses are available from its navigation menu.
Cashiers, inventory personnel, customers and legacy staff have role-specific
workspaces. Only owners can read costs, financial source records and profit reports.

The Stock tab's Add product button opens a validated product form for name,
classification (stored as `category`), description, selling price, purchase cost,
quantity, unit, and reorder level. Products without descriptions remain readable.
The Add/Edit form supports Add photo, Change photo, and Remove photo. Images are
selected from the gallery, requested at 512px and quality 60, and limited to 120 KB.
Compact thumbnails are stored in Firestore as `imageBase64` with the product, so
no Cloud Storage bucket is needed. They count toward Firestore storage and network
usage; larger catalogs should use dedicated image storage. The inventory displays
saved photos, falling back to placeholders for missing or invalid images. Fully
rebuild after adding the native image picker plugin. Editing product details
preserves stock; use Adjust stock for changes.

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
- Business writes now use an authenticated Firebase callable with role and input validation. Rules deny direct client business writes. Deploy both functions and rules before using the updated app; see [backend deployment](functions/README.md).
- Reports query the selected period and calculate gross profit and estimated net profit without the previous 500-record cutoff. Add server aggregates before scaling to very large transaction volumes.
- This code was assembled without Flutter SDK in the execution environment; it has **not been compiled or tested on a device**. Run `flutter analyze`, test in the Firebase Emulator Suite, and fix any SDK/version-specific issues before deployment.
- Firestore may require indexes depending on future query changes; check console prompts.
- Role assignment, stock history and detailed digital receipts are available. Expiry/batch tracking, refunds, durable offline checkout, receipt PDFs and tax computation remain outside scope.

## Seed sample products and expenses

Sign in as an active owner and click **Seed sample data** (cloud upload icon) in the Owner console, then **Seed Firebase**. This writes 8 products with generated illustrated PNG thumbnails and 5 expenses to the configured Firestore database. Images use the existing imageBase64 field; Cloud Storage is not required. Prices and expenses are sample Philippine peso amounts. Sample expenses affect profit reports.

The seeder uses stable demo- document IDs and a single transaction. Repeated runs skip existing records, preserving stock changes, product edits, and expense history. Nothing is seeded automatically at startup or during tests. Deploy the callable backend and rules first; the seeder uses the owner-authorized backend.

## Role workspaces and backend deployment

See [functions/README.md](functions/README.md) for deployment, existing-store catalog/receipt migration, role assignment, permissions and emulator checks. Customers browse with an approved account; ordering remains outside the initial scope.

