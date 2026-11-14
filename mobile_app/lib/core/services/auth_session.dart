import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthSession extends ChangeNotifier {
  AuthSession(this._client) {
    final auth = _client?.auth;
    if (auth == null) return;
    _onSession(auth.currentSession);
    _events = auth.onAuthStateChange.listen(
      (event) => _onSession(event.session),
      onError: (Object _) => _onSession(null),
    );
  }

  final SupabaseClient? _client;
  StreamSubscription<AuthState>? _events;
  Session? _session;
  Set<String> _roles = const {};
  int _revision = 0;

  bool get isConfigured => _client != null;
  bool get isSignedIn => _session != null;
  String? get userId => _session?.user.id;
  SupabaseClient? get authenticatedClient => isSignedIn ? _client : null;
  String? get phone => _session?.user.phone;
  bool get isTechnician => _roles.contains('technician');
  bool get isPlatformAdmin => _roles.contains('platform_admin');

  static String? egyptianPhone(String value) {
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const easternDigits = '۰۱۲۳۴۵۶۷۸۹';
    final phone = value.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (match) {
      final digit = match.group(0)!;
      final index = arabicDigits.indexOf(digit);
      return (index == -1 ? easternDigits.indexOf(digit) : index).toString();
    }).replaceAll(RegExp(r'[\s()-]'), '');
    if (RegExp(r'^01[0125][0-9]{8}$').hasMatch(phone)) {
      return '+20${phone.substring(1)}';
    }
    return RegExp(r'^\+201[0125][0-9]{8}$').hasMatch(phone) ? phone : null;
  }

  Future<void> requestCode(String phone) =>
      _client!.auth.signInWithOtp(phone: phone);

  Future<void> verifyCode(String phone, String code) async {
    final response = await _client!.auth.verifyOTP(
      phone: phone,
      token: code,
      type: OtpType.sms,
    );
    final session = response.session;
    if (session == null) throw const AuthException('Missing session');
    _onSession(session);
  }

  Future<void> signOut() async {
    await _client!.auth.signOut();
    _onSession(null);
  }

  void _onSession(Session? session) {
    if (identical(session, _session)) return;
    _session = session;
    _roles = const {};
    final revision = ++_revision;
    notifyListeners();
    if (session != null) unawaited(_loadRoles(revision));
  }

  Future<void> _loadRoles(int revision) async {
    try {
      final roles = await _client!.rpc<List<dynamic>>('khadamat_my_roles');
      if (_revision != revision) return;
      _roles = roles.whereType<String>().toSet();
      notifyListeners();
    } on Exception {
      // Elevated access stays locked if the role check cannot finish.
    }
  }

  @override
  void dispose() {
    _revision++;
    unawaited(_events?.cancel());
    super.dispose();
  }
}

class AuthSessionScope extends InheritedNotifier<AuthSession> {
  const AuthSessionScope({
    super.key,
    required AuthSession session,
    required super.child,
  }) : super(notifier: session);

  static AuthSession of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthSessionScope>()!.notifier!;
}
