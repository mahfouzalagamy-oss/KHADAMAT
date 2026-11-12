import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/theme.dart';
import '../../shared/models/app_models.dart';
import '../../shared/widgets/ai_diagnosis_modal.dart';
import '../../shared/widgets/home_passport_modal.dart';
import '../../shared/widgets/payment_sandbox_modal.dart';
import '../../shared/widgets/role_header_bar.dart';
import '../../shared/widgets/spare_parts_catalog_modal.dart';
import '../../shared/widgets/warranty_certificate_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStateService.instance,
      builder: (context, _) {
        final state = AppStateService.instance;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: Column(
                  children: [
                    const RoleHeaderBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildPortalView(context, state),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: 0,
            selectedItemColor: AppColors.syaanhOrange,
            unselectedItemColor: AppColors.customerPrimary,
            type: BottomNavigationBarType.fixed,
            onTap: (i) {
              if (i == 1) AiSmartDiagnosisModal.show(context);
              if (i == 2) SparePartsCatalogModal.show(context);
              if (i == 3) HomePassportModal.show(context);
              if (i == 4) Navigator.pushNamed(context, AppRoutes.registerTech);
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
              BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_rounded), label: 'تشخيص AI'),
              BottomNavigationBarItem(icon: Icon(Icons.verified_outlined), label: 'أسعار القطع'),
              BottomNavigationBarItem(icon: Icon(Icons.workspace_premium_outlined), label: 'جواز المنزل'),
              BottomNavigationBarItem(icon: Icon(Icons.badge_outlined), label: 'توثيق فني'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortalView(BuildContext context, AppStateService state) {
    if (state.currentRole == 1) return _buildTechnicianPortal(context, state);
    if (state.currentRole == 2) return _buildCompaniesPortal(context, state);
    if (state.currentRole == 3) return _buildAdminPortal(context, state);
    return _buildLuxuryCustomerPortal(context, state);
  }

  // 1. بوابة العميل الفاخرة والمختصرة (مستوحاة من صيانة قطر)
  Widget _buildLuxuryCustomerPortal(BuildContext context, AppStateService state) {
    final filtered = state.services.where((s) => _searchQuery.trim().isEmpty || s.name.contains(_searchQuery.trim())).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // البنر الملكي المختصر
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF081F36), Color(0xFF0F385C)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: AppColors.customerPrimary.withAlpha(40), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('خدمات | KHADAMAT', style: TextStyle(color: AppColors.syaanhOrange, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      SizedBox(height: 2),
                      Text('صيانة منزلك بضغطة زر', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                        icon: const Icon(Icons.emergency_rounded, size: 18),
                        label: const Text('طوارئ 45 د'),
                        onPressed: () {
                          final o = state.triggerSosEmergencyOrder(
                            serviceName: 'كهرباء',
                            urgentDescription: 'طلب طوارئ سريع',
                            address: state.selectedCity,
                          );
                          Navigator.pushNamed(context, AppRoutes.trackOrder, arguments: {'orderId': o.id});
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.syaanhOrange),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text('تشخيص ذكي'),
                        onPressed: () => AiSmartDiagnosisModal.show(context),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'ابحث عن الخدمة (تكييف، سباكة، كهرباء...)',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.syaanhOrange),
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // صف الأيقونات الذكية الأربع (كلمات مختصرة جداً)
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.spaceBetween,
          children: [
            _quickFeatureTile(Icons.verified_outlined, 'أسعار القطع', AppColors.syaanhOrange, () => SparePartsCatalogModal.show(context)),
            _quickFeatureTile(Icons.workspace_premium_outlined, 'جواز المنزل', AppColors.companyPrimary, () => HomePassportModal.show(context)),
            _quickFeatureTile(Icons.shield_outlined, 'الأمان العائلي', AppColors.success, () => HomePassportModal.showFamilySafeModeDialog(context, state.activeOrder)),
            _quickFeatureTile(
              Icons.account_balance_wallet_outlined,
              'محفظتي (${state.customerWallet.toInt()})',
              AppColors.customerPrimary,
              () => PaymentSandboxModal.show(
                context,
                title: 'شحن المحفظة (+10% هدية)',
                amount: 200,
                onPaymentSuccess: (m, r) => state.rechargeWalletViaSandbox(200, m, r),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // شبكة الأقسام الفاخرة (أيقونة بارزة + اسم القسم + السعر فقط)
        const Text('اختر الخدمة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.customerPrimary)),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final int cols = constraints.maxWidth > 680 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.25,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final s = filtered[i];
                return InkWell(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.createOrder, arguments: {'service': s.name}),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: s.color.withAlpha(22),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s.icon, color: s.color, size: 30),
                        ),
                        const SizedBox(height: 10),
                        Text(s.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.customerPrimary)),
                        const SizedBox(height: 4),
                        Text('من ${s.priceRange}', style: const TextStyle(fontSize: 12, color: AppColors.syaanhOrange, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 22),

        // الطلبات النشطة بتصميم مختصر ونظيف
        const Text('طلباتي الجارية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.customerPrimary)),
        const SizedBox(height: 10),
        ...state.orders.map((o) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.customerPrimary,
                  child: Icon(o.isSosEmergency ? Icons.emergency : Icons.handyman_rounded, color: Colors.white, size: 18),
                ),
                title: Text('${o.serviceName} • ${o.statusText}', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${o.technicianName} • ${o.price} ج.م', style: const TextStyle(fontSize: 12)),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.customerPrimary),
                      onPressed: () => WarrantyCertificateModal.show(context, o),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        state.activeOrderId = o.id;
                        Navigator.pushNamed(context, AppRoutes.trackOrder, arguments: {'orderId': o.id});
                      },
                      child: const Text('التفاصيل'),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _quickFeatureTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 215,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 17, backgroundColor: color.withAlpha(24), child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.customerPrimary))),
          ],
        ),
      ),
    );
  }

  // 2. بوابة الفني المختصرة
  Widget _buildTechnicianPortal(BuildContext context, AppStateService state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.technicianPrimary, borderRadius: BorderRadius.circular(20)),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('بوابة الفني المعتمد', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  Text('صافي الأرباح: ${state.technicianEarnings.toInt()} ج.م', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.badge_outlined, size: 16),
                label: const Text('توثيق هوية فني'),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.registerTech),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...state.orders.map((o) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${o.serviceName} (#${o.id})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        Chip(label: Text('${o.statusText} • PIN: ${o.pinCode}')),
                      ],
                    ),
                    Text('${o.customerName} • ${o.address}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (o.statusIndex < 4)
                          ElevatedButton(
                            onPressed: () => state.advanceOrderStatus(o.id),
                            child: Text('تحديث إلى: ${OrderItemModel.statusLabels[(o.statusIndex + 1).clamp(0, 4)]}'),
                          ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add_circle_outline, size: 15),
                          label: const Text('إضافة قطعة غيار'),
                          onPressed: () => SparePartsCatalogModal.show(context, orderIdForQuote: o.id),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.camera_alt_outlined, size: 15),
                          label: const Text('رفع صورة'),
                          onPressed: () => state.addOrderMaintenancePhoto(o.id, isAfterPhoto: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  // 3. بوابة الشركات المختصرة
  Widget _buildCompaniesPortal(BuildContext context, AppStateService state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.companyPrimary, borderRadius: BorderRadius.circular(20)),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('بوابة الشركات والمقاولين (B2B)', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              Text('إدارة أساطيل الفنيين وعقود الصيانة السنوية AMC', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...state.companies.map((c) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.companyPrimary, child: Icon(Icons.domain_rounded, color: Colors.white)),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${c.specialty} • الأسطول: ${c.techniciansCount} فني • العقود: ${c.activeAmcContracts}', style: const TextStyle(fontSize: 12)),
                trailing: Chip(label: Text('${c.rating} ★', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: AppColors.success),
              ),
            )),
      ],
    );
  }

  // 4. صفحة الإدارة والمراجع المختصرة
  Widget _buildAdminPortal(BuildContext context, AppStateService state) {
    final int totalSales = state.orders.fold<int>(0, (sum, o) => sum + o.price);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.customerPrimary, borderRadius: BorderRadius.circular(20)),
          child: Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 12,
            runSpacing: 10,
            children: [
              _statCol('الطلبات', '${state.orders.length}'),
              _statCol('المبيعات', '$totalSales ج.م'),
              _statCol('العمولة (15%)', '${(totalSales * 0.15).toInt()} ج.م'),
              _statCol('الفنيون', '${state.technicians.length}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('اعتماد هوية الفنيين (KYC)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...state.technicians.map((t) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: Icon(t.isVerified ? Icons.verified_user : Icons.pending_actions, color: t.isVerified ? AppColors.success : AppColors.syaanhOrange),
                title: Text('${t.name} • ${t.specialty}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('رقم الهوية: ${t.nationalId} • ${t.approvalStatusArabic}', style: const TextStyle(fontSize: 12)),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    if (!t.isVerified)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                        onPressed: () => state.reviewTechnicianApplication(t.id, approve: true),
                        child: const Text('موافقة ✅'),
                      ),
                    if (t.isVerified)
                      OutlinedButton(
                        onPressed: () => state.reviewTechnicianApplication(t.id, approve: false),
                        child: const Text('إيقاف'),
                      ),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 16),
        const Text('تحديث أسعار كتالوج قطع الغيار', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...state.sparePartsCatalog.take(4).map((p) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('السعر الرسمي: ${p.officialPrice} ج.م'),
                trailing: OutlinedButton(
                  onPressed: () => state.updateSparePartPrice(p.id, p.officialPrice + 20),
                  child: const Text('+20 ج.م'),
                ),
              ),
            )),
      ],
    );
  }

  Widget _statCol(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: AppColors.syaanhOrange, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}