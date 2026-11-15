import 'package:flutter/material.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/theme.dart';
import '../../shared/models/app_models.dart';
import '../../shared/widgets/home_passport_modal.dart';
import '../../shared/widgets/payment_sandbox_modal.dart';
import '../../shared/widgets/role_header_bar.dart';
import '../../shared/widgets/spare_parts_catalog_modal.dart';
import '../../shared/widgets/warranty_certificate_modal.dart';

class TrackOrderScreen extends StatefulWidget {
  final String? orderId;
  const TrackOrderScreen({super.key, this.orderId});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  final _chatCtrl = TextEditingController();

  OrderItemModel get _order {
    final state = AppStateService.instance;
    if (widget.orderId != null) {
      for (final o in state.orders) {
        if (o.id == widget.orderId) return o;
      }
    }
    return state.activeOrder;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStateService.instance,
      builder: (context, _) {
        final state = AppStateService.instance;
        final order = _order;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  children: [
                    const RoleHeaderBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildStatusCard(context, state, order),
                            const SizedBox(height: 12),
                            _buildQuoteAndPhotosCard(context, state, order),
                            const SizedBox(height: 12),
                            _buildChatCard(state, order),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(BuildContext context, AppStateService state, OrderItemModel order) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text('${order.serviceName} (#${order.id})', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                Chip(
                  label: Text(
                    order.isPaid ? 'مدفوع ✅ (+${order.cashbackAmount} كاش باك)' : 'المطلوب: ${order.price}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  backgroundColor: order.isPaid ? AppColors.success : AppColors.syaanhOrange,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('الفني: ${order.technicianName} • كود الباب PIN: ${order.pinCode}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.customerPrimary)),
            Text('${order.address} • ${order.appointmentSlot}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(OrderItemModel.statusLabels.length, (i) {
                final done = order.statusIndex >= i;
                return Chip(
                  avatar: Icon(done ? Icons.check_circle : Icons.circle_outlined, size: 15, color: done ? Colors.white : Colors.grey),
                  label: Text(OrderItemModel.statusLabels[i], style: TextStyle(color: done ? Colors.white : AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                  backgroundColor: done ? AppColors.success : Colors.grey.shade200,
                );
              }),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!order.isPaid)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE60000)),
                    icon: const Icon(Icons.phone_android, size: 15),
                    label: const Text('فودافون كاش (+10%)'),
                    onPressed: () => PaymentSandboxModal.show(
                      context,
                      title: 'سداد #${order.id}',
                      amount: order.price,
                      initialGateway: 'vodafone',
                      onPaymentSuccess: (m, r) => state.markOrderPaid(order.id, m, r),
                    ),
                  ),
                if (!order.isPaid)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4C1D95)),
                    icon: const Icon(Icons.account_balance, size: 15),
                    label: const Text('إنستا باي (+10%)'),
                    onPressed: () => PaymentSandboxModal.show(
                      context,
                      title: 'سداد #${order.id}',
                      amount: order.price,
                      initialGateway: 'instapay',
                      onPaymentSuccess: (m, r) => state.markOrderPaid(order.id, m, r),
                    ),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.phone_in_talk, size: 15),
                  label: const Text('اتصال مشفر'),
                  onPressed: () => HomePassportModal.showEncryptedCallDialog(context, order),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.shield, size: 15, color: AppColors.success),
                  label: const Text('الأمان العائلي'),
                  onPressed: () => HomePassportModal.showFamilySafeModeDialog(context, order),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, size: 15),
                  label: const Text('الضمان PDF'),
                  onPressed: () => WarrantyCertificateModal.show(context, order),
                ),
                if (order.statusIndex < 4)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.customerPrimary),
                    onPressed: () => state.advanceOrderStatus(order.id),
                    child: const Text('المرحلة التالية ⬅'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteAndPhotosCard(BuildContext context, AppStateService state, OrderItemModel order) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('المقايسة الإلكترونية وتوثيق الصور', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (order.officialSparePartsUsed.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: order.officialSparePartsUsed.map((p) => Text('• $p', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success))).toList(),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 15),
                  label: const Text('إضافة قطعة من الكتالوج'),
                  onPressed: () => SparePartsCatalogModal.show(context, orderIdForQuote: order.id),
                ),
                if (!order.isQuoteApproved)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    icon: const Icon(Icons.check, size: 15),
                    label: const Text('اعتماد المقايسة (-50)'),
                    onPressed: () => state.approveElectronicQuoteWithInspectionDeduction(order.id),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt, size: 15),
                  label: Text('صور قبل (${order.beforePhotos.length}) / بعد (${order.afterPhotos.length})'),
                  onPressed: () => state.addOrderMaintenancePhoto(order.id, isAfterPhoto: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatCard(AppStateService state, OrderItemModel order) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('سجل المحادثة والإيصالات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: order.chatMessages
                  .map((m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                          child: Text(m, style: const TextStyle(fontSize: 12)),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _chatCtrl, decoration: const InputDecoration(labelText: 'رسالة سريعة...'))),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    state.sendChatMessage(order.id, state.currentRole == 1 ? 'الفني' : 'العميل', _chatCtrl.text);
                    _chatCtrl.clear();
                  },
                  child: const Text('إرسال'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}