import 'package:flutter_test/flutter_test.dart';
import 'package:verifier_app/common/app_logger.dart';

void main() {
  test(
    'each level method produces a LogRecord with the matching level and tag',
    () {
      final records = <LogRecord>[];
      final logger = AppLogger('test.tag', sink: records.add);

      logger.debug('a');
      logger.info('b');
      logger.warn('c');
      logger.error('d');

      expect(records.map((r) => r.level).toList(), [
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warn,
        LogLevel.error,
      ]);
      expect(records.every((r) => r.tag == 'test.tag'), isTrue);
      expect(records.map((r) => r.message).toList(), ['a', 'b', 'c', 'd']);
    },
  );

  test('fields are passed through unmodified', () {
    final records = <LogRecord>[];
    final logger = AppLogger('test.tag', sink: records.add);

    logger.info(
      'tap outcome',
      fields: {'result': 'approved', 'readLatencyMs': 1800},
    );

    expect(records.single.fields, {
      'result': 'approved',
      'readLatencyMs': 1800,
    });
  });

  test(
    'error() carries the error object and stack trace separately from fields',
    () {
      final records = <LogRecord>[];
      final logger = AppLogger('test.tag', sink: records.add);
      final stackTrace = StackTrace.current;

      logger.error(
        'sync failed',
        error: 'timeout',
        stackTrace: stackTrace,
        fields: {'batchSize': 12},
      );

      final record = records.single;
      expect(record.error, 'timeout');
      expect(record.stackTrace, stackTrace);
      expect(record.fields, {'batchSize': 12});
    },
  );

  test('without an injected sink, logging does not throw', () {
    const logger = AppLogger('test.tag');
    expect(() => logger.info('hello'), returnsNormally);
  });
}
