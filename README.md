# TapID

A demo door-scan app: an attendant scans the PDF417 barcode on the back of
a US driver's license/ID with their phone's camera, the app reads off the
holder's age and issuing state, and the attendant makes the call. This is a
personal demo project, not a production or compliance product.

## How it works

- `apps/verifier_app` — the Flutter app. One screen, `DoorScreen`: scan →
  see age/state → attendant allows or refuses → next patron.
- The scan itself sits behind a small interface, `VerificationRail`
  (`lib/rails/verification_rail.dart`) — one async call in, one outcome
  out. `Pdf417Rail` is the real implementation: camera scan + a small AAMVA
  barcode parser (`lib/rails/aamva.dart`). `MockRail` backs the test suite
  and can script canned outcomes for a demo without a camera.
- `services/api/lambda` + `infra/terraform` — a minimal AWS backend (API
  Gateway + Lambda + DynamoDB) the app reports outcomes to. Deployed to a
  `dev` environment already: `GET /v1/config`, `POST /v1/shifts`,
  `POST /v1/events`, bearer-auth'd with a static demo token (not a
  production credential).
- `lib/api/tapid_api_client.dart` — the client that POSTs each decision to
  `POST /v1/events`. Fire-and-forget: a dropped connection or backend error
  never blocks the door screen, it's just logged. Only constructed if the
  backend's base URL and token are supplied at run time (see below); the
  app still works as a scan-only demo without them.

## Running it

Needs a physical iPhone — barcode scanning needs a real camera, which the
iOS Simulator doesn't have.

1. `cd apps/verifier_app && flutter pub get`
2. Open `ios/Runner.xcworkspace` in Xcode once. Select the `Runner` target →
   Signing & Capabilities → sign in with your own Apple ID and pick it as
   the Team (a free personal account works fine).
3. Plug in an iPhone. Enable Developer Mode on it (Settings → Privacy &
   Security → Developer Mode). If prompted, trust the computer and the new
   developer certificate.
4. To also report outcomes to the backend, get the live API endpoint and
   demo token (`terraform output api_endpoint` in
   `infra/terraform/environments/dev`, and the `demo_api_token` value from
   wherever it's kept — it's a sensitive Terraform variable, not committed)
   and run:
   ```
   flutter run -d <device> \
     --dart-define=API_BASE_URL=<api_endpoint> \
     --dart-define=API_BEARER_TOKEN=<demo_api_token>
   ```
   Without those two `--dart-define`s, the app runs exactly as before —
   scanning works, nothing gets reported anywhere.
5. Tap "Scan ID" and scan the barcode on the back of a US driver's license
   or state ID.

## Known limitations

- The barcode isn't cryptographically signed by the issuing state — unlike
  what an Apple Wallet ID would have provided, this is only as trustworthy
  as the plastic card itself (the same trust level as a bouncer eyeballing
  a card today, not a regression below it).
- All 50 states + DC + US territories are recognized by barcode issuer code
  (IIN), from AAMVA's published table (`lib/rails/aamva.dart`). Canadian and
  Mexican issuers are recognized but intentionally out of scope — they come
  back `unsupportedIssuer` with the jurisdiction still filled in. A wholly
  unrecognized IIN comes back `unsupportedIssuer` with no jurisdiction.
- No shift-claim/staff-login screen yet — the backend has a stubbed
  PIN-roster endpoint for it (`POST /v1/shifts`), unused by the app so far.
  Every event reported to the backend is attributed to a fixed placeholder
  shift ID (`sft_demo`) instead.
- Reporting to the backend is fire-and-forget, not a real offline-outbox —
  if a POST fails, it's logged and dropped, not retried or queued.

See [`ROADMAP.md`](ROADMAP.md) for what's done and what's next.
