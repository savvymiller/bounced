import 'package:flutter/material.dart';

import '../screens/door/barcode_scan_screen.dart';
import 'aamva.dart';
import 'verification_outcome.dart';
import 'verification_rail.dart';

/// Reads the PDF417 barcode on the back of a physical ID via the device
/// camera. No Apple entitlement required, unlike the ProximityReader-based
/// rail this replaced before it was ever built.
///
/// Mirrors [MockRail]'s shape: [scan] and [now] are injectable so the
/// decision logic (age math, expiration, issuer support) is fully
/// unit-testable against the shared contract suite without a camera —
/// `test/rails/pdf417_rail_test.dart` does exactly that. [Pdf417Rail.live]
/// wires the real camera for production.
class Pdf417Rail implements VerificationRail {
  Pdf417Rail({
    required Future<String?> Function() scan,
    DateTime Function() now = DateTime.now,
  }) : _scan = scan,
       _now = now;

  /// Pushes [BarcodeScanScreen] on the app's root navigator and resolves
  /// with whatever it pops — the raw barcode payload, or null on cancel.
  factory Pdf417Rail.live({required GlobalKey<NavigatorState> navigatorKey}) {
    return Pdf417Rail(
      scan: () => navigatorKey.currentState!.push<String?>(
        MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
      ),
    );
  }

  final Future<String?> Function() _scan;
  final DateTime Function() _now;
  int _counter = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<VerificationOutcome> beginVerification() async {
    final started = DateTime.now();
    final raw = await _scan();
    final readLatency = DateTime.now().difference(started);
    final eventId =
        'pdf417_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
    final occurredAt = _now().toUtc();

    if (raw == null) {
      return VerificationOutcome(
        eventId: eventId,
        result: RailResult.cancelled,
        occurredAt: occurredAt,
        readLatency: readLatency,
      );
    }

    return switch (parseAamva(raw)) {
      AamvaMalformed() => VerificationOutcome(
        eventId: eventId,
        result: RailResult.readFailed,
        occurredAt: occurredAt,
        readLatency: readLatency,
      ),
      AamvaUnsupportedIssuer(jurisdiction: final jurisdiction) =>
        VerificationOutcome(
          eventId: eventId,
          result: RailResult.unsupportedIssuer,
          issuingJurisdiction: jurisdiction,
          occurredAt: occurredAt,
          readLatency: readLatency,
        ),
      AamvaParsed(
        expiration: final expiration,
        dateOfBirth: final dob,
        jurisdiction: final jurisdiction,
      ) =>
        _decide(
          expiration: expiration,
          dob: dob,
          jurisdiction: jurisdiction,
          eventId: eventId,
          occurredAt: occurredAt,
          readLatency: readLatency,
        ),
    };
  }

  VerificationOutcome _decide({
    required DateTime expiration,
    required DateTime dob,
    required String jurisdiction,
    required String eventId,
    required DateTime occurredAt,
    required Duration readLatency,
  }) {
    final now = _now();
    if (expiration.isBefore(now)) {
      return VerificationOutcome(
        eventId: eventId,
        result: RailResult.expired,
        issuingJurisdiction: jurisdiction,
        occurredAt: occurredAt,
        readLatency: readLatency,
      );
    }

    final ageAtLeast21 = _ageInYears(dob, now) >= 21;
    return VerificationOutcome(
      eventId: eventId,
      result: ageAtLeast21 ? RailResult.approved : RailResult.declined,
      ageAtLeast21: ageAtLeast21,
      issuingJurisdiction: jurisdiction,
      occurredAt: occurredAt,
      readLatency: readLatency,
    );
  }
}

int _ageInYears(DateTime dob, DateTime now) {
  var age = now.year - dob.year;
  final hadBirthdayThisYear =
      now.month > dob.month || (now.month == dob.month && now.day >= dob.day);
  if (!hadBirthdayThisYear) age--;
  return age;
}
