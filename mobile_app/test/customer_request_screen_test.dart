import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khadamat_app/core/services/auth_session.dart';
import 'package:khadamat_app/main.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  testWidgets('reviews an Egyptian service request with entered details', (
    tester,
  ) async {
    final session = AuthSession(null);
    await tester.pumpWidget(KhadamatOfficialApp(session: session));
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('تكييف وتبريد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(find.text('هذا الحقل مطلوب.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'التكييف لا يبرد');
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'حي الجامعة');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'شارع الجمهورية، عمارة ١٢');
    await tester.ensureVisible(find.text('مراجعة الطلب'));
    await tester.tap(find.text('مراجعة الطلب'));
    await tester.pumpAndSettle();

    expect(find.text('راجع طلبك'), findsOneWidget);
    expect(find.text('التكييف لا يبرد'), findsOneWidget);
    expect(find.text('حي الجامعة، شارع الجمهورية، عمارة ١٢'), findsOneWidget);
    final submit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'متابعة برقم الهاتف'),
    );
    expect(submit.onPressed, isNull);

    await tester.scrollUntilVisible(find.text('الرجوع للتعديل'), 180);
    await tester.tap(find.text('الرجوع للتعديل'));
    await tester.pumpAndSettle();
    expect(find.text('حي الجامعة'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('حفظ كمسودة'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('حفظ كمسودة'));
    await tester.pumpAndSettle();
    expect(find.text('تم حفظ المسودة على هذا الجهاز.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('تكييف وتبريد'));
    await tester.pumpAndSettle();
    expect(find.text('التكييف لا يبرد'), findsOneWidget);
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(find.text('حي الجامعة'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
