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

  void _showKycModal(BuildContext context, AppStateService state, TechnicianItemModel t) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('فحص هوية الفني: ${t.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.customerPrimary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('بطاقة تحقيق الهوية الوطنية (KYC)', style: TextStyle(color: AppColors.goldAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          Icon(Icons.verified_user, color: AppColors.goldAccent, size: 20),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(t.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                      Text('الرقم القومي / الإقامة: ${t.nationalId}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('التخصص: ${t.specialty} • ${t.city}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(dense: true, leading: const Icon(Icons.badge, color: AppColors.success), title: Text('الوجه الأمامي: ${t.idFrontPhoto}')),
                ListTile(dense: true, leading: const Icon(Icons.badge_outlined, color: AppColors.success), title: Text('الوجه الخلفي: ${t.idBackPhoto}')),
                ListTile(dense: true, leading: const Icon(Icons.workspace_premium, color: AppColors.success), title: Text('الفيش والخبرة: ${t.certificatePhoto}')),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                state.reviewTechnicianApplication(t.id, approve: false);
                Navigator.pop(ctx);
              },
              child: const Text('رفض ❌'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () {
                state.reviewTechnicianApplication(t.id, approve: true);
                Navigator.pop(ctx);
              },
              child: const Text('موافقة وتوثيق ✅'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCompanyModal(BuildContext context, AppStateService state) {
    final nameCtrl = TextEditingController();
    final crCtrl = TextEditingController(text: 'CR-778291');
    final fleetCtrl = TextEditingController(text: '20');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('تسجيل شركة صيانة معتمدة (B2B)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة الرسمي', prefixIcon: Icon(Icons.domain))),
              const SizedBox(height: 10),
              TextField(controller: crCtrl, decoration: const InputDecoration(labelText: 'رقم السجل التجاري CR', prefixIcon: Icon(Icons.badge))),
              const SizedBox(height: 10),
              TextField(controller: fleetCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الفنيين في الأسطول', prefixIcon: Icon(Icons.groups))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  state.registerNewCompany(
                    name: nameCtrl.text.trim(),
                    specialty: 'صيانة متكاملة وعقود سنوية AMC',
                    city: state.selectedCity,
                    commercialReg: crCtrl.text.trim(),
                    taxCard: 'TX-882-109',
                    fleetCount: int.tryParse(fleetCtrl.text.trim()) ?? 15,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('اعتماد الشركة'),
            ),
          ],
        ),
      ),
    );
  }

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
                constraints: const BoxConstraints(maxWidth: 960),
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

  Widget _buildLuxuryCustomerPortal(BuildContext context, AppStateService state) {
    final filtered = state.services.where((s) => _searchQuery.trim().isEmpty || s.name.contains(_searchQuery.trim())).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: SizedBox(
            height: 235,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  state.heroBannerImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF07162C), Color(0xFF0F385C)]),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF040D1A).withAlpha(235),
                        const Color(0xFF07162C).withAlpha(140),
                      ],
                      begin: Alignment.bottomRight,
                      end: Alignment.topLeft,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.goldAccent.withAlpha(35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.goldAccent),
                        ),
                        child: const Text(
                          'خدمات • KHADAMAT VIP',
                          style: TextStyle(color: AppColors.goldAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'صيانة منزلك بفخامة وأمان',
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'فنيون موثقون بالهوية • أسعار قطع رسمية • ضمان ذهبي 100%',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                            icon: const Icon(Icons.emergency_rounded, size: 17),
                            label: const Text('طوارئ 45 د'),
                            onPressed: () {
                              final o = state.triggerSosEmergencyOrder(
                                serviceName: 'كهرباء وإنارة',
                                urgentDescription: 'بلاغ طوارئ سريع',
                                address: state.selectedCity,
                              );
                              Navigator.pushNamed(context, AppRoutes.trackOrder, arguments: {'orderId': o.id});
                            },
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.goldAccent, foregroundColor: AppColors.customerPrimary),
                            icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                            label: const Text('تشخيص ذكي AI'),
                            onPressed: () => AiSmartDiagnosisModal.show(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'ابحث عن الخدمة (تكييف، سباكة، كهرباء، كاميرات...)',
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.syaanhOrange),
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 14),
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
        const SizedBox(height: 22),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('أقسام الصيانة الفاخرة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.customerPrimary)),
            Text('معاينة 50 تُخصم عند الإصلاح', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.syaanhOrange)),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final int cols = constraints.maxWidth > 720 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.08,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final s = filtered[i];
                return InkWell(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.createOrder, arguments: {'service': s.name}),
                  borderRadius: BorderRadius.circular(22),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          s.bgImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: s.color),
                        ),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF040D1A).withAlpha(230),
                                const Color(0xFF040D1A).withAlpha(45),
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.topLeft,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(110),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.goldAccent.withAlpha(140)),
                                  ),
                                  child: Icon(s.icon, color: AppColors.goldAccent, size: 20),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.name,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white, height: 1.1),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.syaanhOrange,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'من ${s.minPrice}',
                                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 22),
        const Text('طلباتي الجارية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.customerPrimary)),
        const SizedBox(height: 10),
        ...state.orders.map((o) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AppColors.border)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.customerPrimary,
                  child: Icon(o.isSosEmergency ? Icons.emergency : Icons.handyman_rounded, color: AppColors.goldAccent, size: 18),
                ),
                title: Text('${o.serviceName} • ${o.statusText}', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${o.technicianName} • الإجمالي: ${o.price}', style: const TextStyle(fontSize: 12)),
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
        width: 220,
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

  Widget _buildTechnicianPortal(BuildContext context, AppStateService state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.technicianPrimary, borderRadius: BorderRadius.circular(22)),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('بوابة الفني المعتمد VIP', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  Text('صافي الأرباح: ${state.technicianEarnings.toInt()} • التقييم: 4.9★', style: const TextStyle(color: AppColors.goldAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(state.technicianOnlineToggle ? 'متاح لاستقبال الطلبات 🟢' : 'مشغول مؤقتاً 🔴'),
                    selected: state.technicianOnlineToggle,
                    onSelected: (_) => state.toggleTechnicianOnlineStatus(),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.badge_outlined, size: 16),
                    label: const Text('توثيق هوية فني'),
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.registerTech),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...state.orders.map((o) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                    const SizedBox(height: 12),
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
                          label: const Text('إضافة قطعة للمقايسة'),
                          onPressed: () => SparePartsCatalogModal.show(context, orderIdForQuote: o.id),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.camera_alt_outlined, size: 15),
                          label: const Text('رفع صورة العمل'),
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

  Widget _buildCompaniesPortal(BuildContext context, AppStateService state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.companyPrimary, borderRadius: BorderRadius.circular(22)),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('بوابة الشركات والمقاولين (B2B)', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  Text('إدارة أساطيل الفنيين وعقود الصيانة السنوية للقصور والشركات AMC', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_business, size: 16),
                    label: const Text('تسجيل شركة جديدة'),
                    onPressed: () => _showAddCompanyModal(context, state),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const Text('ضم فني للأسطول'),
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.registerTech),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...state.companies.map((c) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: AppColors.companyPrimary, child: Icon(Icons.domain_rounded, color: Colors.white)),
                title: Text('${c.name} (${c.city})', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${c.specialty} • السجل: ${c.commercialReg}\nالأسطول: ${c.techniciansCount} فني • العقود السنوية AMC: ${c.activeAmcContracts} عقد'),
                isThreeLine: true,
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.customerPrimary),
                  onPressed: () => state.incrementCompanyAmcContract(c.id),
                  child: const Text('+ عقد سنوي AMC'),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildAdminPortal(BuildContext context, AppStateService state) {
    final int totalSales = state.orders.fold<int>(0, (sum, o) => sum + o.price);
    final int pendingKyc = state.technicians.where((t) => !t.isVerified).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppColors.customerPrimary, borderRadius: BorderRadius.circular(22)),
          child: Wrap(
            alignment: WrapAlignment.spaceAround,
            spacing: 12,
            runSpacing: 10,
            children: [
              _statCol('الطلبات', '${state.orders.length}'),
              _statCol('المبيعات', '$totalSales'),
              _statCol('العمولة (15%)', '${(totalSales * 0.15).toInt()}'),
              _statCol('بانتظار الهوية', '$pendingKyc'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('1. مراجعة واعتماد هوية الفنيين (KYC Inspector)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...state.technicians.map((t) => Card(
              color: t.isVerified ? Colors.white : const Color(0xFFFFF7ED),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: Icon(t.isVerified ? Icons.verified_user : Icons.pending_actions, color: t.isVerified ? AppColors.success : AppColors.syaanhOrange),
                title: Text('${t.name} • ${t.specialty}', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('الهوية: ${t.nationalId} • ${t.approvalStatusArabic}', style: const TextStyle(fontSize: 12)),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    OutlinedButton(
                      onPressed: () => _showKycModal(context, state, t),
                      child: const Text('معاينة الهوية'),
                    ),
                    if (!t.isVerified)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                        onPressed: () => state.reviewTechnicianApplication(t.id, approve: true),
                        child: const Text('موافقة ✅'),
                      ),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 16),
        const Text('2. التحكم في أسعار الأقسام وكتالوج القطع الرسمي', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...state.services.take(4).map((s) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: Icon(s.icon, color: AppColors.syaanhOrange),
                title: Text('قسم: ${s.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('يبدأ من: ${s.minPrice}'),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    OutlinedButton(onPressed: () => state.updateServiceBasePrice(s.id, -20), child: const Text('-20')),
                    OutlinedButton(onPressed: () => state.updateServiceBasePrice(s.id, 20), child: const Text('+20')),
                  ],
                ),
              ),
            )),
        ...state.sparePartsCatalog.take(4).map((p) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.verified_outlined, color: AppColors.customerPrimary),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('السعر الرسمي: ${p.officialPrice}'),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    OutlinedButton(onPressed: () => state.updateSparePartPrice(p.id, p.officialPrice - 20), child: const Text('-20')),
                    OutlinedButton(onPressed: () => state.updateSparePartPrice(p.id, p.officialPrice + 20), child: const Text('+20')),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _statCol(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: AppColors.goldAccent, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}