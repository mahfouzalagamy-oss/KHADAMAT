import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/theme.dart';
import '../models/app_models.dart';

class HomePassportModal extends StatefulWidget {
  const HomePassportModal({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: HomePassportModal(),
      ),
    );
  }

  static void showEncryptedCallDialog(BuildContext context, OrderItemModel order) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.customerPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('اتصال صوتي مشفر 🔒', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(radius: 34, backgroundColor: AppColors.syaanhOrange, child: Icon(Icons.phone_in_talk, color: Colors.white, size: 32)),
              const SizedBox(height: 12),
              Text(order.technicianName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('الرقم محجوب للخصوصية: +974 / +20-XXXX', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إنهاء المكالمة'),
            ),
          ],
        ),
      ),
    );
  }

  static void showFamilySafeModeDialog(BuildContext context, OrderItemModel order) {
    final state = AppStateService.instance;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Row(
            children: [
              Icon(Icons.shield, color: AppColors.success),
              SizedBox(width: 8),
              Expanded(child: Text('درع الأمان العائلي 🛡️', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الفني المعتمد: ${order.technicianName} (موثق الهوية ✅)', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('كود الأمان عند الباب PIN: ${order.pinCode}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.syaanhOrange)),
              const SizedBox(height: 10),
              SelectableText(order.familyTrackingLink, style: const TextStyle(fontSize: 12, color: AppColors.technicianPrimary)),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 15),
              label: const Text('نسخ الرابط'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: order.familyTrackingLink));
                Navigator.pop(ctx);
              },
            ),
            ElevatedButton(
              onPressed: () {
                state.toggleFamilySafeMode(order.id);
                Navigator.pop(ctx);
              },
              child: const Text('تفعيل البث الحي'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  State<HomePassportModal> createState() => _HomePassportModalState();
}

class _HomePassportModalState extends State<HomePassportModal> {
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = AppStateService.instance;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('جواز السفر الصياني للمنزل', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...state.homeAppliances.map((app) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFF0FDF4),
                        child: Text('${app.healthScore}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                      ),
                      title: Text('${app.name} (${app.brand})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('آخر صيانة: ${app.lastMaintenanceDate} • القادم: ${app.nextReminderDate}', style: const TextStyle(fontSize: 11)),
                    ),
                  )),
              const Divider(),
              Row(
                children: [
                  Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'الجهاز'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _brandCtrl, decoration: const InputDecoration(labelText: 'الماركة'))),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  if (_nameCtrl.text.trim().isNotEmpty) {
                    setState(() {
                      state.addHomeApplianceToPassport(name: _nameCtrl.text.trim(), brand: _brandCtrl.text.trim(), room: 'المنزل');
                      _nameCtrl.clear();
                      _brandCtrl.clear();
                    });
                  }
                },
                child: const Text('إضافة جهاز جديد'),
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
    );
  }
}