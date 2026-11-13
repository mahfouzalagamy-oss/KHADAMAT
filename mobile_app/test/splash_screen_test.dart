import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khadamat_app/core/routes/app_routes.dart';
import 'package:khadamat_app/features/splash/splash_screen.dart';

void main() {
  testWidgets('shows KHADAMAT before navigating to home', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const SplashScreen(),
        routes: {
          AppRoutes.home: (_) => const Scaffold(body: Text('Home route')),
        },
      ),
    );

    expect(find.text('KHADAMAT'), findsOneWidget);
    expect(find.text('Home route'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    expect(find.text('Home route'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });
}
