# Roadmap

## Done

- Flutter app shell (DI, routing, theming)
- Door screen (mock-backed)
- `Pdf417Rail`: barcode-scan verification rail, replacing the never-built
  Apple Wallet rail (no Apple entitlement needed)
- Demo AWS backend: API Gateway + Lambda + DynamoDB, deployed to `dev`
- Repo cleanup + doc simplification
- Fixed the barcode scanner issuer bug: a real card thought to be from
  Illinois came back `unsupportedIssuer` — turned out to actually be an
  Indiana-issued ID (IIN `636037`), which simply wasn't in the curated
  table yet (not a wrong mapping, a missing one). Diagnosed with a
  temporary debug log of the raw scanned payload, added `'636037': 'IN'`
  to `supportedIins`, then removed the debug log again (it would otherwise
  print barcode PII — name, address, DL number — to the device log on
  every future unsupported scan).
- Expanded `supportedIins` to all 50 states + DC + US territories, sourced
  from AAMVA's published IIN table rather than guessed. Canadian/Mexican
  issuers are now recognized-but-unsupported (`knownUnsupportedIins`)
  instead of wholly unknown.

## Next

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
- Offline queue if the network drops mid-demo
