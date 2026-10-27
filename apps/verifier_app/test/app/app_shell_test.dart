import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:verifier_app/app/app_shell.dart';
import 'package:verifier_app/rails/mock_rail.dart';
import 'package:verifier_app/rails/verification_rail.dart';
import 'package:verifier_app/screens/door/door_screen.dart';

void main() {
  testWidgets('renders the door screen and makes the rail available via DI', (
    tester,
  ) async {
    final rail = MockRail();

    await tester.pumpWidget(AppShell(rail: rail));
    await tester.pumpAndSettle();

    expect(find.text('Tap to Verify'), findsOneWidget);

    final context = tester.element(find.byType(DoorScreen));
    expect(Provider.of<VerificationRail>(context, listen: false), same(rail));
  });
}
