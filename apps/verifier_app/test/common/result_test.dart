import 'package:flutter_test/flutter_test.dart';
import 'package:verifier_app/common/result.dart';

void main() {
  test('Success reports isSuccess and folds to onSuccess', () {
    const result = Result<int>.success(42);

    expect(result.isSuccess, isTrue);
    expect(result.isFailure, isFalse);
    expect(
      result.fold(onSuccess: (v) => 'got $v', onFailure: (e, st) => 'error'),
      'got 42',
    );
  });

  test('Failure reports isFailure and folds to onFailure with the error and stack trace', () {
    final stackTrace = StackTrace.current;
    final result = Result<int>.failure('boom', stackTrace);

    expect(result.isSuccess, isFalse);
    expect(result.isFailure, isTrue);
    expect(
      result.fold(
        onSuccess: (v) => 'got $v',
        onFailure: (e, st) => '$e/${st == stackTrace}',
      ),
      'boom/true',
    );
  });

  test('Failure stack trace is optional', () {
    const result = Result<int>.failure('boom');

    expect(
      result.fold(onSuccess: (v) => null, onFailure: (e, st) => st),
      isNull,
    );
  });
}
