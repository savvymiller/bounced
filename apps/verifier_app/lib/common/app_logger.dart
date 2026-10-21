import 'dart:developer' as developer;

enum LogLevel { debug, info, warn, error }

/// One structured log line. [fields] is encouraged over string
/// interpolation so a future log sink (CloudWatch, eventually) can filter
/// on specific keys — see docs/THREAT_MODEL.md#t4-pii-leakage-via-client-logs.
///
/// This logger does not enforce a field allowlist itself; the actual
/// PII guarantee for tap data lives one layer down, in VerificationOutcome's
/// restricted field set (ADR-0001) — logging that type is safe by
/// construction, not because this logger checks anything.
class LogRecord {
  const LogRecord({
    required this.level,
    required this.tag,
    required this.message,
    this.fields = const {},
    this.error,
    this.stackTrace,
  });

  final LogLevel level;
  final String tag;
  final String message;
  final Map<String, Object?> fields;
  final Object? error;
  final StackTrace? stackTrace;
}

typedef LogSink = void Function(LogRecord record);

void _defaultSink(LogRecord record) {
  developer.log(
    record.fields.isEmpty
        ? record.message
        : '${record.message} ${record.fields}',
    name: record.tag,
    level: switch (record.level) {
      LogLevel.debug => 500,
      LogLevel.info => 800,
      LogLevel.warn => 900,
      LogLevel.error => 1000,
    },
    error: record.error,
    stackTrace: record.stackTrace,
  );
}

/// A tagged, leveled, structured-field logger. [sink] defaults to
/// `dart:developer`'s log() but is injectable so tests can assert on what
/// was logged without depending on the real output stream.
class AppLogger {
  const AppLogger(this.tag, {LogSink? sink}) : _sink = sink ?? _defaultSink;

  final String tag;
  final LogSink _sink;

  void debug(String message, {Map<String, Object?> fields = const {}}) =>
      _log(LogLevel.debug, message, fields);

  void info(String message, {Map<String, Object?> fields = const {}}) =>
      _log(LogLevel.info, message, fields);

  void warn(String message, {Map<String, Object?> fields = const {}}) =>
      _log(LogLevel.warn, message, fields);

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const {},
  }) {
    _sink(
      LogRecord(
        level: LogLevel.error,
        tag: tag,
        message: message,
        fields: fields,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  void _log(LogLevel level, String message, Map<String, Object?> fields) {
    _sink(LogRecord(level: level, tag: tag, message: message, fields: fields));
  }
}
