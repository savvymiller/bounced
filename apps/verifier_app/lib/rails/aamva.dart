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

/// Every US state, DC, and US territory's AAMVA Issuer Identification
/// Number, from AAMVA's published IIN table
/// (https://www.aamva.org/identity/issuer-identification-numbers-(iin)).
/// Deliberately excludes IIN 636027 ("State Dept." — diplomatic IDs, not a
/// state-issued driver's license/ID).
const supportedIins = {
  '636033': 'AL',
  '636059': 'AK',
  '604427': 'AS', // American Samoa
  '636026': 'AZ',
  '636021': 'AR',
  '636014': 'CA',
  '636020': 'CO',
  '636006': 'CT',
  '636011': 'DE',
  '636043': 'DC',
  '636010': 'FL',
  '636055': 'GA',
  '636019': 'GU', // Guam
  '636047': 'HI',
  '636050': 'ID',
  '636035': 'IL',
  '636037': 'IN',
  '636018': 'IA',
  '636022': 'KS',
  '636046': 'KY',
  '636007': 'LA',
  '636041': 'ME',
  '636003': 'MD',
  '636002': 'MA',
  '636032': 'MI',
  '636038': 'MN',
  '636051': 'MS',
  '636030': 'MO',
  '636008': 'MT',
  '604430': 'MP', // Northern Mariana Islands
  '636054': 'NE',
  '636049': 'NV',
  '636039': 'NH',
  '636036': 'NJ',
  '636009': 'NM',
  '636001': 'NY',
  '636004': 'NC',
  '636034': 'ND',
  '636023': 'OH',
  '636058': 'OK',
  '636029': 'OR',
  '636025': 'PA',
  '604431': 'PR', // Puerto Rico
  '636052': 'RI',
  '636005': 'SC',
  '636042': 'SD',
  '636053': 'TN',
  '636015': 'TX',
  '636040': 'UT',
  '636024': 'VT',
  '636000': 'VA',
  '636062': 'VI', // US Virgin Islands
  '636045': 'WA',
  '636061': 'WV',
  '636031': 'WI',
  '636060': 'WY',
};

/// Non-US AAMVA jurisdictions (Canadian provinces/territories, Mexican
/// states) — real, recognized issuers, deliberately out of scope for this
/// US-focused demo. Lets an `unsupportedIssuer` outcome still report a
/// real jurisdiction instead of an unresolvable one, for a card from one
/// of these.
const knownUnsupportedIins = {
  '604426': 'PE', // Prince Edward Island
  '604428': 'QC', // Quebec
  '604429': 'YT', // Yukon
  '604432': 'AB', // Alberta
  '604433': 'NU', // Nunavut
  '636012': 'ON', // Ontario
  '636013': 'NS', // Nova Scotia
  '636016': 'NF', // Newfoundland
  '636017': 'NB', // New Brunswick
  '636028': 'BC', // British Columbia
  '636044': 'SK', // Saskatchewan
  '636048': 'MB', // Manitoba
  '636056': 'CU', // Coahuila, Mexico
  '636057': 'HL', // Hidalgo, Mexico
};

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
