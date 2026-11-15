import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/theme.dart';

class RoleHeaderBar extends StatelessWidget {
  const RoleHeaderBar({super.key});

  void _showNotificationsModal(BuildContext context, AppStateService state) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('الإشعارات الحية'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: state.notifications
                    .take(8)
                    .map((n) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.notifications_active, color: AppColors.syaanhOrange, size: 18),
                          title: Text(n, style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
              ),
            ),
          ),
          actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        ),
      ),
    );
  }

  void _showSupabaseModal(BuildContext context, AppStateService state) {
    final urlCtrl = TextEditingController(text: state.supabaseUrl);
    final keyCtrl = TextEditingController(text: state.supabaseAnonKey);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إعدادات السحابة (Supabase)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Project URL')),
              const SizedBox(height: 10),
              TextField(controller: keyCtrl, decoration: const InputDecoration(labelText: 'Anon Key')),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                await state.configureSupabaseConnection(urlCtrl.text, keyCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('مزامنة الآن'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateService.instance;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(color: AppColors.customerPrimary),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              InkWell(
                onTap: () => Navigator.pushNamed(context, AppRoutes.splash),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.syaanhOrange, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('خدمات', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0)),
                        Text('KHADAMAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.goldAccent, letterSpacing: 2.8)),
                      ],
                    ),
                  ],
                ),
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  InkWell(
                    onTap: () => _showSupabaseModal(context, state),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: state.isCloudConnected ? AppColors.success.withAlpha(40) : Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: state.isCloudConnected ? AppColors.success : Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 9, color: state.isCloudConnected ? AppColors.success : AppColors.goldAccent),
                          const SizedBox(width: 5),
                          Text(state.isCloudConnected ? 'متصل' : 'السحابة', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButton<String>(
                      value: state.selectedCity,
                      dropdownColor: AppColors.customerPrimary,
                      underline: const SizedBox(),
                      isDense: true,
                      iconEnabledColor: Colors.white,
                      items: state.egyptCities
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) state.setCity(v);
                      },
                    ),
                  ),
                  IconButton(
                    icon: Badge(
                      backgroundColor: AppColors.syaanhOrange,
                      label: Text('${state.notifications.length}'),
                      child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                    ),
                    onPressed: () => _showNotificationsModal(context, state),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_outline_rounded, color: Colors.white),
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _roleTab(context, 0, 'العميل', Icons.person_rounded, AppColors.customerPrimary),
              _roleTab(context, 1, 'الفني', Icons.handyman_rounded, AppColors.technicianPrimary),
              _roleTab(context, 2, 'الشركات', Icons.domain_rounded, AppColors.companyPrimary),
              _roleTab(context, 3, 'الإدارة', Icons.verified_user_rounded, AppColors.adminPrimary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roleTab(BuildContext context, int index, String label, IconData icon, Color color) {
    final state = AppStateService.instance;
    final bool selected = state.currentRole == index;
    return InkWell(
      onTap: () {
        state.setRole(index);
        if (ModalRoute.of(context)?.settings.name != AppRoutes.home) {
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (r) => false);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}