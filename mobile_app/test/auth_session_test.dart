import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:khadamat_app/core/services/auth_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('normalizes supported Egyptian mobile number formats', () {
    expect(AuthSession.egyptianPhone('010 1234 5678'), '+201012345678');
    expect(AuthSession.egyptianPhone('+٢٠١١١٢٣٤٥٦٧٨'), '+201112345678');
    expect(AuthSession.egyptianPhone('۰۱۲۱۲۳۴۵۶۷۸'), '+201212345678');
    expect(AuthSession.egyptianPhone('01312345678'), isNull);
    expect(AuthSession.egyptianPhone('+97412345678'), isNull);
  });

  test('only a successful server verification creates a session', () async {
    final requests = <String>[];
    final client = SupabaseClient(
      'https://example.invalid',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request.url.path);
        switch (request.url.path) {
          case '/auth/v1/otp':
            expect(jsonDecode(request.body)['phone'], '+201012345678');
            return _json({});
          case '/auth/v1/verify':
            expect(jsonDecode(request.body)['type'], 'sms');
            return _json({'msg': 'Invalid token', 'code': 403}, status: 403);
          default:
            fail('Unexpected request to ${request.url.path}');
        }
      }),
    );
    final session = AuthSession(client);
    addTearDown(() async {
      session.dispose();
      await client.dispose();
    });
    await session.requestCode('+201012345678');
    await expectLater(
      session.verifyCode('+201012345678', '123456'),
      throwsA(isA<AuthException>()),
    );
    expect(session.isSignedIn, isFalse);
    expect(session.isPlatformAdmin, isFalse);
    expect(requests, ['/auth/v1/otp', '/auth/v1/verify']);
  });

  test('uses server roles after sign-in and clears them on sign-out', () async {
    String encode(Object data) =>
        base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
    final token = '${encode({'alg': 'HS256'})}.'
        '${encode({'sub': 'test-user', 'exp': 4102444800})}.signature';
    final client = SupabaseClient(
      'https://example.invalid',
      'public-test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        switch (request.url.path) {
          case '/auth/v1/verify':
            return _json({
              'access_token': token,
              'refresh_token': 'test-refresh-token',
              'expires_in': 3600,
              'token_type': 'bearer',
              'user': {
                'id': 'test-user',
                'aud': 'authenticated',
                'phone': '201012345678',
                'created_at': '2026-01-01T00:00:00Z',
                'user_metadata': {'role': 'platform_admin'},
              },
            });
          case '/rest/v1/rpc/khadamat_my_roles':
            expect(request.headers['authorization'], 'Bearer $token');
            return http.Response(
              '["customer","technician"]',
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          case '/auth/v1/logout':
            return http.Response('', 204);
          default:
            fail('Unexpected request to ${request.url.path}');
        }
      }),
    );
    final session = AuthSession(client);
    addTearDown(() async {
      session.dispose();
      await client.dispose();
    });

    await session.verifyCode('+201012345678', '321654');
    await Future<void>.delayed(Duration.zero);
    expect(session.isSignedIn, isTrue);
    expect(session.isTechnician, isTrue);
    expect(session.isPlatformAdmin, isFalse);

    await session.signOut();
    expect(session.isSignedIn, isFalse);
    expect(session.isTechnician, isFalse);
  });
}

http.Response _json(Map<String, Object?> value, {int status = 200}) =>
    http.Response(jsonEncode(value), status,
        headers: {'content-type': 'application/json'});
