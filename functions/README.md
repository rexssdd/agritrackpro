# Store backend and role workspaces

The updated app requires `storeOperation` and the updated Firestore rules together.
Do not distribute the updated client until both are deployed. Existing clients
that write directly to Firestore will stop working after the new rules deploy.

## Deployment

Use Node.js 22 and a Firebase project enabled for Cloud Functions billing.
Install dependencies locally before deploying from the project root:

```powershell
cd functions
npm.cmd ci
npm.cmd test
cd ..
firebase.cmd deploy --only functions,firestore:rules --project agritrackpro-73030
flutter pub get
flutter run
```

The callable runs in `us-central1`; the Flutter client uses that default region.
No service account key belongs in the app or this repository.

## Existing stores

1. Sign in with an active owner profile (`users/{uid}`, `role: owner`, `active: true`).
2. In Owner console, tap **Publish existing catalog and receipts** (sync icon).
   This backfills `catalog` and `receipts` in pages, without changing existing
   inventory, expenses, or sales. It can safely be repeated.
3. In Accounts, choose the person's **Assigned workspace**, then enable access.
   New registrations remain pending until approved. Existing `staff` accounts
   keep checkout and stock adjustment access, but lose profit/cost access.
4. Use **Seed sample data** only if demo records are wanted. The seeder also
   publishes its product thumbnails to the safe catalog. Sample expenses affect
   profit reports.

| Role | Workspace and permissions |
| --- | --- |
| Owner | Dashboard, products and purchase costs, checkout, all receipts, accounts, profit reports, expenses, stock history, seeding and migration |
| Cashier | Checkout, customer payment references, own receipt history and daily collection totals by payment method |
| Inventory | Add/edit products without purchase-cost access, restock/deduct stock, movement history, record/view operating expenses |
| Customer | Approved-account catalog: search, prices, images, descriptions and stock availability; purchase in store |
| Staff (legacy) | Checkout, own receipts, stock adjustment and movement history; no costs/profits/accounts |

Inventory-created products require the owner to save their purchase cost before
the backend permits selling them. Inventory edits preserve existing stock and
hidden purchase costs; quantity changes use audited adjustment operations.

## Data and validation

- `products` and `sales` are owner-readable financial source records.
- `catalog` is an explicit allowlist of product fields without purchase costs.
- `receipts` excludes sale costs and per-item unit costs. Cashiers can query only
  receipts with their own `cashierId`. Customers cannot read receipts or sales.
- All business writes go through the callable; direct client writes are denied.
- Checkout reads current server prices and costs, validates stock, then writes
  the sale, safe receipt, stock balances, safe catalog and movement logs atomically.
- Non-cash payments need a reference and an employee's explicit verification.
  This records manual verification; it does not contact a payment provider.
- Checkout retries reuse a request ID. After an uncertain response the cart is
  locked until that transaction is retried. Retrying cannot deduct stock twice.
  Pending carts are not yet persisted across app termination: check receipts
  before starting a replacement transaction after restarting the app.
- Expenses use the selected business date for reporting, plus a separate
  server `recordedAt` audit timestamp. Future dates and invalid amounts are rejected.
- Reports query the selected period without the previous 500-record cutoff.
  The dashboard queries the current month. Large stores should add server
  aggregates before scaling beyond per-period client-side summaries.
- Stock history shows the latest 300 movements, clearly labeled in the UI.
- Product images remain compact base64 PNG/JPEG data in Firestore. No Storage
  bucket or external image host is required.

## Emulator verification

Integration tests refuse to run unless a Firestore emulator is configured.
From the project root, with Java installed:

```powershell
firebase.cmd emulators:exec --project demo-agritrack --only firestore,auth,functions "npm.cmd --prefix functions run test:integration"
```

The emulator suite uses only the demo project. It checks private-data access,
role assignment, direct-write denial, trusted prices, exactly-once checkout,
stock and audit consistency, payment checks, expense dates, and inventory edits.
Run `flutter test` for UI tests and `npm.cmd --prefix functions test` for pure
backend validation tests.

Remaining scope: customer orders, payment gateways, printable/PDF receipts,
refunds, expiry/batch tracking, tax accounting, and durable offline checkout.
