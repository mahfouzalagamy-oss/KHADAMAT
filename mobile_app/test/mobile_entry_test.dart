import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khadamat_app/core/services/auth_session.dart';
import 'package:khadamat_app/main.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('cold launch opens catalog, then request and back to catalog',
      (tester) async {
    final session = AuthSession(null);
    addTearDown(session.dispose);
    await _launch(tester, session);

    expect(find.text('محتاج خدمة إيه؟'), findsOneWidget);
    expect(find.text('إيه المشكلة؟'), findsNothing);
    expect(find.text('الرئيسية'), findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);

    await tester.enterText(find.byType(TextField), 'اجهزة');
    await tester.pumpAndSettle();
    expect(find.text('تكييف وتبريد'), findsNothing);
    await tester.tap(find.text('أجهزة منزلية'));
    await tester.pumpAndSettle();
    expect(find.text('إيه المشكلة؟'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('محتاج خدمة إيه؟'), findsOneWidget);

    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    expect(find.textContaining('نسخة المعاينة'), findsOneWidget);
    await tester.tap(find.text('رجوع'));
    await tester.pumpAndSettle();
    expect(find.text('محتاج خدمة إيه؟'), findsOneWidget);
  });

  testWidgets('account validates a number and accepts an Arabic SMS code',
      (tester) async {
    final session = _TestPhoneSession();
    addTearDown(session.dispose);
    await _launch(tester, session);

    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('أرسل رمز التحقق'));
    await tester.pumpAndSettle();
    expect(find.text('اكتب رقم موبايل مصري صحيح.'), findsOneWidget);
    expect(session.requestedPhone, isNull);

    await tester.enterText(find.byType(TextField), '٠١٠١٢٣٤٥٦٧٨');
    await tester.tap(find.text('أرسل رمز التحقق'));
    await tester.pumpAndSettle();
    expect(session.requestedPhone, '+201012345678');
    expect(find.text('أدخل رمز التحقق'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '١٢٣٤٥٦');
    await tester.tap(find.text('تأكيد الرمز'));
    await tester.pumpAndSettle();
    expect(session.verifiedCode, '123456');
    expect(find.text('محتاج خدمة إيه؟'), findsOneWidget);
    expect(find.text('حسابي'), findsOneWidget);
  });
}

Future<void> _launch(WidgetTester tester, AuthSession session) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(320, 640);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(KhadamatOfficialApp(session: session));
  await tester.pump(const Duration(milliseconds: 2500));
  await tester.pumpAndSettle();
}

class _TestPhoneSession extends AuthSession {
  _TestPhoneSession() : super(null);

  String? requestedPhone;
  String? verifiedCode;

  @override
  bool get isConfigured => true;

  @override
  bool get isSignedIn => verifiedCode != null;

  @override
  Future<void> requestCode(String phone) async {
    requestedPhone = phone;
  }

  @override
  Future<void> verifyCode(String phone, String code) async {
    expect(phone, requestedPhone);
    verifiedCode = code;
    notifyListeners();
  }
}
