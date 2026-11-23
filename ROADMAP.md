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
- Connected the frontend to the live API: `lib/api/tapid_api_client.dart`
  POSTs every captured decision to `POST /v1/events`. Provider-injected the
  same way `VerificationRail` is (`app_shell.dart`/`main.dart`), nullable —
  the app runs scan-only if no backend `--dart-define`s are supplied.
  Fire-and-forget from `door_screen.dart`'s `_captureDecision`: a failure
  is logged via `AppLogger`, never blocks or surfaces in the UI. Every
  event uses a fixed placeholder `shiftId` (`sft_demo`) since there's no
  shift-claim UI yet.

## Next

Nothing specifically planned — the core demo loop (scan → decide → report)
is complete end to end. See Stretch below for ideas if picked back up.

## Stretch (not currently planned)

- Shift-claim screen (PIN entry) wired to the existing `POST /v1/shifts`
- Offline queue if the network drops mid-demo
