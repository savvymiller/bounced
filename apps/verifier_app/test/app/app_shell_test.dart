import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:verifier_app/app/app_shell.dart';
import 'package:verifier_app/rails/mock_rail.dart';
import 'package:verifier_app/rails/verification_rail.dart';
import 'package:verifier_app/screens/home/home_placeholder_screen.dart';

void main() {
  testWidgets(
    'renders the home placeholder and makes the rail available via DI',
    (tester) async {
      final rail = MockRail();

      await tester.pumpWidget(AppShell(rail: rail));
      await tester.pumpAndSettle();

      expect(find.text('TapID'), findsWidgets);
      expect(find.text('Door screen lands in PR-09.'), findsOneWidget);

      final context = tester.element(find.byType(HomePlaceholderScreen));
      expect(Provider.of<VerificationRail>(context, listen: false), same(rail));
    },
  );
}
