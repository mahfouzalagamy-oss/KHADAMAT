import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/theme.dart';
import '../../shared/widgets/payment_sandbox_modal.dart';
import '../../shared/widgets/role_header_bar.dart';

class CreateOrderScreen extends StatefulWidget {
  final String? initialServiceName;
  const CreateOrderScreen({super.key, this.initialServiceName});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  late String _selectedService;
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController(text: 'منطقة اللؤلؤة / مدينة نصر - فيلا 18');
  final _priceCtrl = TextEditingController(text: '150');

  String _appointmentSlot = 'طوارئ فورية (45 دقيقة)';
  String? _selectedTechId;
  String _paymentMethod = 'فودافون كاش / Paymob';

  final List<String> _slots = const [
    'طوارئ فورية (45 دقيقة)',
    'اليوم مساءً (4م - 7م)',
    'غداً صباحاً (10ص - 1م)',
  ];

  @override
  void initState() {
    super.initState();
    final services = AppStateService.instance.services;
    _selectedService = widget.initialServiceName ?? services.first.name;
    final found = services.where((s) => s.name == _selectedService).toList();
    if (found.isNotEmpty) {
      _priceCtrl.text = found.first.minPrice.toString();
    }
  }

  void _submitOrder({bool isPaid = false, String? ref}) {
    final state = AppStateService.instance;
    final order = state.createOrder(
      serviceName: _selectedService,
      description: _descCtrl.text,
      photos: const ['قبل_صورة_العطل.jpg', 'وسم_الأمان_العائلي'],
      address: _addressCtrl.text,
      mapCoords: 'GPS متصل',
      appointmentSlot: _appointmentSlot,
      assignmentMode: 'عروض أسعار',
      paymentMethod: _paymentMethod,
      price: int.tryParse(_priceCtrl.text.trim()) ?? 150,
      manualTechId: _selectedTechId,
      isPaidInitially: isPaid,
      paymentRef: ref,
    );
    Navigator.pushReplacementNamed(context, AppRoutes.trackOrder, arguments: {'orderId': order.id});
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateService.instance;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('حجز خدمة صيانة سريع', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                                TextButton.icon(
                                  icon: const Icon(Icons.arrow_back, size: 16),
                                  label: const Text('رجوع'),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: state.services.map((s) {
                                final sel = s.name == _selectedService;
                                return ChoiceChip(
                                  avatar: Icon(s.icon, size: 16, color: sel ? Colors.white : AppColors.syaanhOrange),
                                  label: Text(s.name, style: TextStyle(color: sel ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.bold)),
                                  selected: sel,
                                  selectedColor: AppColors.customerPrimary,
                                  onSelected: (_) => setState(() {
                                    _selectedService = s.name;
                                    _priceCtrl.text = s.minPrice.toString();
                                  }),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _descCtrl,
                              decoration: const InputDecoration(labelText: 'وصف مختصر للعطل', prefixIcon: Icon(Icons.build_circle_outlined)),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _addressCtrl,
                              decoration: const InputDecoration(labelText: 'العنوان (المنطقة / الشارع / الفيلا)', prefixIcon: Icon(Icons.location_on_outlined)),
                            ),
                            const SizedBox(height: 14),
                            const Text('الموعد:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _slots.map((slot) {
                                final sel = _appointmentSlot == slot;
                                return ChoiceChip(
                                  label: Text(slot, style: const TextStyle(fontSize: 12)),
                                  selected: sel,
                                  onSelected: (_) => setState(() => _appointmentSlot = slot),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),
                            const Text('اختر العرض والفني المعتمد:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            ...state.technicians.where((t) => t.isVerified).map((t) {
                              final chosen = _selectedTechId == t.id;
                              final int p = (int.tryParse(_priceCtrl.text) ?? 150) + (t.id == 'TECH-1' ? 0 : 25);
                              return Card(
                                color: chosen ? const Color(0xFFFFF7ED) : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: chosen ? AppColors.syaanhOrange : AppColors.border),
                                ),
                                child: ListTile(
                                  dense: true,
                                  onTap: () => setState(() {
                                    _selectedTechId = t.id;
                                    _priceCtrl.text = p.toString();
                                  }),
                                  leading: const Icon(Icons.verified_user, color: AppColors.customerPrimary),
                                  title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${t.rating}★ • يبعد ${t.distanceKm} كم'),
                                  trailing: Text('$p', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.syaanhOrange, fontSize: 15)),
                                ),
                              );
                            }),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              children: ['فودافون كاش / Paymob', 'إنستا باي / Fawry', 'كاش عند الإتمام'].map((m) {
                                final sel = _paymentMethod == m;
                                return ChoiceChip(
                                  label: Text(m),
                                  selected: sel,
                                  onSelected: (_) => setState(() => _paymentMethod = m),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle),
                              label: const Text('تأكيد الحجز الآن'),
                              onPressed: () {
                                final int price = int.tryParse(_priceCtrl.text.trim()) ?? 150;
                                if (_paymentMethod == 'كاش عند الإتمام') {
                                  _submitOrder(isPaid: false);
                                } else {
                                  PaymentSandboxModal.show(
                                    context,
                                    title: 'سداد طلب ($_selectedService)',
                                    amount: price,
                                    initialGateway: _paymentMethod.contains('إنستا') ? 'instapay' : 'vodafone',
                                    onPaymentSuccess: (_, ref) => _submitOrder(isPaid: true, ref: ref),
                                  );
                                }
                              },
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