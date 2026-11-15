import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/role_header_bar.dart';

class TechnicianRegistrationScreen extends StatefulWidget {
  const TechnicianRegistrationScreen({super.key});

  @override
  State<TechnicianRegistrationScreen> createState() => _TechnicianRegistrationScreenState();
}

class _TechnicianRegistrationScreenState extends State<TechnicianRegistrationScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nationalIdCtrl = TextEditingController();
  String _selectedSpecialty = 'تكييف وتبريد';
  String _idFrontFile = 'هوية_أمامي.jpg';
  String _idBackFile = 'هوية_خلفي.jpg';

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty || _nationalIdCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل الاسم ورقم الهوية')));
      return;
    }
    final state = AppStateService.instance;
    state.registerNewTechnicianApplication(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? '01000000000' : _phoneCtrl.text.trim(),
      specialty: _selectedSpecialty,
      city: state.selectedCity,
      nationalId: _nationalIdCtrl.text.trim(),
      idFrontPhoto: _idFrontFile,
      idBackPhoto: _idBackFile,
      certificatePhoto: 'شهادة_خبرة_وفيش.jpg',
      experienceYears: 5,
      walletNumber: _phoneCtrl.text.trim(),
    );
    state.setRole(3);
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateService.instance;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                const RoleHeaderBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('تسجيل فني جديد وتوثيق الهوية (KYC)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 14),
                            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم الفني الكامل', prefixIcon: Icon(Icons.person))),
                            const SizedBox(height: 10),
                            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'رقم الجوال', prefixIcon: Icon(Icons.phone_android))),
                            const SizedBox(height: 10),
                            TextField(controller: _nationalIdCtrl, decoration: const InputDecoration(labelText: 'رقم البطاقة / الإقامة القطرية QID', prefixIcon: Icon(Icons.badge))),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: state.services.map((s) {
                                final sel = _selectedSpecialty == s.name;
                                return ChoiceChip(
                                  label: Text(s.name),
                                  selected: sel,
                                  onSelected: (_) => setState(() => _selectedSpecialty = s.name),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),
                            ListTile(
                              tileColor: const Color(0xFFF0FDF4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              leading: const Icon(Icons.check_circle, color: AppColors.success),
                              title: Text('مرفقات الهوية: $_idFrontFile / $_idBackFile', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              trailing: OutlinedButton(
                                onPressed: () => setState(() {
                                  _idFrontFile = 'هوية_محدثة_${DateTime.now().second}.jpg';
                                }),
                                child: const Text('تحديث الصورة'),
                              ),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.verified_user),
                              label: const Text('إرسال للمراجعة والموافقة الفورية'),
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}