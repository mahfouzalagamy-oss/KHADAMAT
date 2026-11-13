import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../models/app_models.dart';

class WarrantyCertificateModal extends StatelessWidget {
  final OrderItemModel order;
  const WarrantyCertificateModal({super.key, required this.order});

  static void show(BuildContext context, OrderItemModel order) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: WarrantyCertificateModal(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('شهادة ضمان خدمات | KHADAMAT (#${order.warrantyNumber})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الخدمة: ${order.serviceName} (#${order.id})', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('الفني المعتمد: ${order.technicianName}'),
            Text('الإجمالي: ${order.price} (${order.isPaid ? "مسدد ✅" : "عند الإتمام"})'),
            const Divider(),
            Text('صور قبل الصيانة: ${order.beforePhotos.length} | صور بعد الإصلاح: ${order.afterPhotos.length}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.qr_code_2, size: 54, color: AppColors.customerPrimary),
                SizedBox(width: 10),
                Expanded(child: Text('ضمان ذهبي رسمي لمدة 30 يوماً من منصة خدمات | KHADAMAT.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              ],
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf, size: 16),
          label: const Text('حفظ PDF'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}