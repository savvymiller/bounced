# Roadmap

## Done

- Flutter app shell (DI, routing, theming)
- Door screen (mock-backed)
- `Pdf417Rail`: barcode-scan verification rail, replacing the never-built
  Apple Wallet rail (no Apple entitlement needed)
- Demo AWS backend: API Gateway + Lambda + DynamoDB, deployed to `dev`
- Repo cleanup + doc simplification (this pass)

## Next

**Fix the barcode scanner issuer bug.** A real Illinois license comes back
`unsupportedIssuer` even though `IL` is already in the curated IIN table in
`lib/rails/aamva.dart` — the IIN value used for it is probably wrong, or the
real header differs slightly from what the parser's regexes assume. Add a
temporary `debugPrint` of the raw scanned payload when `aamva.dart` returns
`AamvaUnsupportedIssuer`, re-scan, read the real IIN out of the log, and fix
`supportedIins`. Don't guess a second value blindly like the first one.

**Connect the frontend to the live API.** The backend already exists and
already defines the contract (`services/api/lambda/handler.js`):
`POST /v1/events` takes `{events: [{eventId, railResult, ageAtLeast21,
humanDecision, refusalReason, issuingJurisdiction, occurredAt, shiftId,
readLatencyMs, syncedOffline}]}`, bearer-auth'd with a static token.
- Add the `http` package.
- New `lib/api/tapid_api_client.dart`: a thin client — base URL + bearer
  token in the constructor, one method `submitEvent(VerificationOutcome,
  {required HumanDecision decision, RefusalReason? reason})` that POSTs to
  `/v1/events` with that shape (a placeholder `shiftId`, since there's no
  shift-claim UI yet).
- Wire it into `door_screen.dart`'s `_captureDecision`: fire the POST best
  effort — log failures, don't block the UI. This is a demo, not a real
  offline-outbox system.
- Pass the base URL and token via `--dart-define` at `flutter run` time.
  Never commit them.
- Provider-inject the client the same way `VerificationRail` is injected
  today (`app_shell.dart`/`main.dart`).

## Stretch (not currently planned)

- Shift-claim screen (PIN entry) wired to the existing `POST /v1/shifts`
- Broader state coverage in the IIN table
- Offline queue if the network drops mid-demo
