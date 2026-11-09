/// Minimal parser for the AAMVA DL/ID subfile text a barcode scanner hands
/// back as a PDF417 barcode's raw string. Real US driver's license/ID
/// barcodes use this format, so this works against real cards, not just
/// fixtures.
///
/// Deliberately narrow: extracts only what the door needs (date of birth,
/// expiration, issuing state) via regex on the well-known three-letter
/// element codes, rather than walking the subfile offset table —
/// real-world lightweight AAMVA readers do this too, since it is robust to
/// the header/version differences between states' encoders. Never extracts
/// name, address, or document number — that data never needs to exist in
/// this process at all.
library;

sealed class AamvaResult {
  const AamvaResult();
}

/// Successfully decoded a supported state's subfile.
final class AamvaParsed extends AamvaResult {
  const AamvaParsed({
    required this.dateOfBirth,
    required this.expiration,
    required this.jurisdiction,
  });

  final DateTime dateOfBirth;
  final DateTime expiration;
  final String jurisdiction;
}

/// The issuer identification number was recognized but isn't in
/// [supportedIins]. [jurisdiction] is populated when we happen to know the
/// state anyway (see [knownUnsupportedIins]) and null otherwise — mirrors
/// how Apple Wallet's `unsupportedIssuer` sometimes does and sometimes
/// doesn't learn the jurisdiction before giving up.
final class AamvaUnsupportedIssuer extends AamvaResult {
  const AamvaUnsupportedIssuer(this.jurisdiction);
  final String? jurisdiction;
}

/// Not a recognizable AAMVA payload at all, or missing a required field.
final class AamvaMalformed extends AamvaResult {
  const AamvaMalformed();
}

/// Curated subset of AAMVA Issuer Identification Numbers this demo
/// supports — the barcode-rail analogue of the README's "~15 jurisdictions"
/// coverage framing for Apple Wallet. The full IIN list is public (AAMVA
/// maintains it) and this map can grow without touching anything else in
/// the rail.
const supportedIins = {
  '636014': 'CA',
  '636001': 'NY',
  '636015': 'TX',
  '636010': 'FL',
  '636025': 'PA',
  '636023': 'OH',
  '636045': 'WA',
  '636032': 'MI',
  '636026': 'AZ',
  '636020': 'CO',
  '636002': 'MA',
  '636036': 'NJ',
  '636000': 'VA',
  '636035': 'IL',
  '636055': 'GA',
};

/// IINs recognized but intentionally left out of [supportedIins], so an
/// `unsupportedIssuer` outcome can still report a real-looking jurisdiction
/// instead of an unresolvable one.
const knownUnsupportedIins = {'636060': 'WY'};

final _iinPattern = RegExp(r'ANSI\s*(\d{6})');
final _dobPattern = RegExp(r'DBB(\d{8})');
final _expirationPattern = RegExp(r'DBA(\d{8})');

AamvaResult parseAamva(String raw) {
  final iinMatch = _iinPattern.firstMatch(raw);
  if (iinMatch == null) return const AamvaMalformed();
  final iin = iinMatch.group(1)!;

  final supported = supportedIins[iin];
  if (supported == null) {
    return AamvaUnsupportedIssuer(knownUnsupportedIins[iin]);
  }

  final dobMatch = _dobPattern.firstMatch(raw);
  final expirationMatch = _expirationPattern.firstMatch(raw);
  if (dobMatch == null || expirationMatch == null) {
    return const AamvaMalformed();
  }

  final dob = _parseMmDdCcYy(dobMatch.group(1)!);
  final expiration = _parseMmDdCcYy(expirationMatch.group(1)!);
  if (dob == null || expiration == null) return const AamvaMalformed();

  return AamvaParsed(
    dateOfBirth: dob,
    expiration: expiration,
    jurisdiction: supported,
  );
}

/// AAMVA's standard US date encoding: MMDDCCYY.
DateTime? _parseMmDdCcYy(String digits) {
  if (digits.length != 8) return null;
  final month = int.tryParse(digits.substring(0, 2));
  final day = int.tryParse(digits.substring(2, 4));
  final year = int.tryParse(digits.substring(4, 8));
  if (month == null || day == null || year == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime.utc(year, month, day);
}
