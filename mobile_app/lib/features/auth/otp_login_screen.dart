import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/theme.dart';

class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  final _nameCtrl = TextEditingController(text: 'أحمد محمود');
  final _phoneCtrl = TextEditingController(text: '01012345678');
  final _otpCtrl = TextEditingController(text: '1234');
  int _role = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دخول خدمات | KHADAMAT')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('خدمات | KHADAMAT', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.customerPrimary)),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          ChoiceChip(label: const Text('عميل'), selected: _role == 0, onSelected: (_) => setState(() => _role = 0)),
                          ChoiceChip(label: const Text('فني'), selected: _role == 1, onSelected: (_) => setState(() => _role = 1)),
                          ChoiceChip(label: const Text('شركة'), selected: _role == 2, onSelected: (_) => setState(() => _role = 2)),
                          ChoiceChip(label: const Text('إدارة'), selected: _role == 3, onSelected: (_) => setState(() => _role = 3)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'الاسم', prefixIcon: Icon(Icons.person))),
                      const SizedBox(height: 12),
                      TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الجوال', prefixIcon: Icon(Icons.phone_android))),
                      const SizedBox(height: 12),
                      TextField(controller: _otpCtrl, decoration: const InputDecoration(labelText: 'كود التحقق OTP (1234)', prefixIcon: Icon(Icons.lock))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          AppStateService.instance.sendOtp(_phoneCtrl.text, _nameCtrl.text, _role);
                          AppStateService.instance.verifyOtp(_otpCtrl.text);
                          Navigator.pushReplacementNamed(context, AppRoutes.home);
                        },
                        child: const Text('دخول فوري'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.badge_outlined, size: 16),
                        label: const Text('تسجيل فني جديد بالهوية'),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.registerTech),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}