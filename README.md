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
4. `flutter run -d <device>`
5. Tap "Scan ID" and scan the barcode on the back of a US driver's license
   or state ID.

## Known limitations

- The barcode isn't cryptographically signed by the issuing state — unlike
  what an Apple Wallet ID would have provided, this is only as trustworthy
  as the plastic card itself (the same trust level as a bouncer eyeballing
  a card today, not a regression below it).
- Only a curated subset of ~15 states' barcode issuer codes (IINs) are
  recognized (`lib/rails/aamva.dart`); anything else comes back
  `unsupportedIssuer`. There's a known mismatch for Illinois — see
  `ROADMAP.md`.
- No shift-claim/staff-login screen yet — the backend has a stubbed
  PIN-roster endpoint for it (`POST /v1/shifts`), unused by the app so far.
- The app doesn't call the backend yet — see `ROADMAP.md`.

See [`ROADMAP.md`](ROADMAP.md) for what's done and what's next.
