import 'package:flutter_test/flutter_test.dart';
import 'package:verifier_app/rails/aamva.dart';

/// Builds a raw AAMVA-ish payload good enough to exercise [parseAamva] —
/// real decoders care about more header bytes than this, but [parseAamva]
/// only looks for the ANSI/IIN marker and the DBB/DBA element codes, so
/// that's all this needs to provide.
String _rawFor({required String iin, String? dob, String? expiration}) {
  final buffer = StringBuffer('@\n\x1e\rANSI ${iin}0902DL00410278ZV03190008DL');
  if (dob != null) buffer.write('DBB$dob');
  if (expiration != null) buffer.write('DBA$expiration');
  return buffer.toString();
}

void main() {
  group('parseAamva', () {
    test('decodes a supported state with DOB and expiration', () {
      final result = parseAamva(
        _rawFor(iin: '636014', dob: '05151990', expiration: '05152030'),
      );

      expect(result, isA<AamvaParsed>());
      final parsed = result as AamvaParsed;
      expect(parsed.jurisdiction, 'CA');
      expect(parsed.dateOfBirth, DateTime.utc(1990, 5, 15));
      expect(parsed.expiration, DateTime.utc(2030, 5, 15));
    });

    test('recognizes every curated supported IIN', () {
      for (final entry in supportedIins.entries) {
        final result = parseAamva(
          _rawFor(iin: entry.key, dob: '01011990', expiration: '01012030'),
        );
        expect(result, isA<AamvaParsed>(), reason: entry.value);
        expect((result as AamvaParsed).jurisdiction, entry.value);
      }
    });

    test('an IIN outside the supported set is unsupportedIssuer, with the '
        'jurisdiction filled in when it happens to be a known one', () {
      final result = parseAamva(
        _rawFor(iin: '636012', dob: '01011990', expiration: '01012030'),
      );

      expect(result, isA<AamvaUnsupportedIssuer>());
      expect((result as AamvaUnsupportedIssuer).jurisdiction, 'ON');
    });

    test('recognizes every curated known-unsupported IIN', () {
      for (final entry in knownUnsupportedIins.entries) {
        final result = parseAamva(
          _rawFor(iin: entry.key, dob: '01011990', expiration: '01012030'),
        );
        expect(result, isA<AamvaUnsupportedIssuer>(), reason: entry.value);
        expect((result as AamvaUnsupportedIssuer).jurisdiction, entry.value);
      }
    });

    test('a wholly unknown IIN is unsupportedIssuer with no jurisdiction', () {
      final result = parseAamva(
        _rawFor(iin: '999999', dob: '01011990', expiration: '01012030'),
      );

      expect(result, isA<AamvaUnsupportedIssuer>());
      expect((result as AamvaUnsupportedIssuer).jurisdiction, isNull);
    });

    test('missing the ANSI/IIN marker entirely is malformed', () {
      expect(parseAamva('not a barcode at all'), isA<AamvaMalformed>());
    });

    test('a supported issuer missing DOB is malformed', () {
      final result = parseAamva(_rawFor(iin: '636014', expiration: '01012030'));
      expect(result, isA<AamvaMalformed>());
    });

    test('a supported issuer missing expiration is malformed', () {
      final result = parseAamva(_rawFor(iin: '636014', dob: '01011990'));
      expect(result, isA<AamvaMalformed>());
    });

    test('an unparseable date is malformed', () {
      final result = parseAamva(
        _rawFor(iin: '636014', dob: '13991990', expiration: '01012030'),
      );
      expect(result, isA<AamvaMalformed>());
    });
  });
}
