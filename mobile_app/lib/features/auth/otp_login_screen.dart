import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/auth_session.dart';

class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _phone;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String failure) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Exception {
      if (mounted) setState(() => _error = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    final phone = AuthSession.egyptianPhone(_phoneController.text);
    if (phone == null) {
      setState(() => _error = 'اكتب رقم موبايل مصري صحيح.');
      return;
    }
    await _run(() async {
      await widget.session.requestCode(phone);
      if (mounted) setState(() => _phone = phone);
    }, 'تعذّر إرسال الرمز. تأكد من الرقم وحاول مرة أخرى بعد قليل.');
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'اكتب رمز التحقق المكوّن من 6 أرقام.');
      return;
    }
    await _run(() async {
      await widget.session.verifyCode(_phone!, code);
      if (mounted) Navigator.of(context).maybePop();
    }, 'تعذّر التحقق من الرمز. تأكد منه أو اطلب رمزًا جديدًا.');
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: session,
          builder: (context, _) => Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!session.isConfigured)
                      const Text('تسجيل الدخول غير متاح في هذه النسخة.')
                    else if (session.isSignedIn) ...[
                      Text(session.phone ?? '',
                          textDirection: TextDirection.ltr),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                  await session.signOut();
                                  if (!mounted) return;
                                  setState(() {
                                    _phone = null;
                                    _codeController.clear();
                                  });
                                }, 'تعذّر تسجيل الخروج. حاول مرة أخرى.'),
                        child: const Text('تسجيل الخروج'),
                      ),
                    ] else ...[
                      Text(
                        _phone == null
                            ? 'سجّل برقم موبايلك'
                            : 'أدخل رمز التحقق',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      if (_phone == null)
                        TextField(
                          controller: _phoneController,
                          enabled: !_busy,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          textDirection: TextDirection.ltr,
                          decoration: const InputDecoration(
                            labelText: 'رقم الموبايل',
                            hintText: '01XXXXXXXXX',
                          ),
                        )
                      else ...[
                        Text(_phone!, textDirection: TextDirection.ltr),
                        TextField(
                          controller: _codeController,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          textDirection: TextDirection.ltr,
                          decoration:
                              const InputDecoration(labelText: 'رمز التحقق'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _phone = null;
                                    _error = null;
                                    _codeController.clear();
                                  }),
                          child: const Text('تغيير الرقم أو طلب رمز جديد'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : _phone == null
                                ? _sendCode
                                : _verifyCode,
                        child: Text(
                            _phone == null ? 'أرسل رمز التحقق' : 'تأكيد الرمز'),
                      ),
                    ],
                    if (_busy) const LinearProgressIndicator(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
