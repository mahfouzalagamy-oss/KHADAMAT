import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

class PaymentSandboxModal extends StatefulWidget {
  final String title;
  final int amount;
  final String initialGateway;
  final void Function(String methodLabel, String referenceCode) onPaymentSuccess;

  const PaymentSandboxModal({
    super.key,
    required this.title,
    required this.amount,
    this.initialGateway = 'vodafone',
    required this.onPaymentSuccess,
  });

  static void show(
    BuildContext context, {
    required String title,
    required int amount,
    String initialGateway = 'vodafone',
    required void Function(String methodLabel, String referenceCode) onPaymentSuccess,
  }) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: PaymentSandboxModal(
          title: title,
          amount: amount,
          initialGateway: initialGateway,
          onPaymentSuccess: onPaymentSuccess,
        ),
      ),
    );
  }

  @override
  State<PaymentSandboxModal> createState() => _PaymentSandboxModalState();
}

class _PaymentSandboxModalState extends State<PaymentSandboxModal> {
  late String _gateway;
  final _walletPhoneCtrl = TextEditingController(text: '01010101010');
  final _walletOtpCtrl = TextEditingController(text: '123456');

  @override
  void initState() {
    super.initState();
    _gateway = widget.initialGateway;
  }

  @override
  Widget build(BuildContext context) {
    final bool isVodafone = _gateway == 'vodafone';
    final int cashback = (widget.amount * 0.10).round();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('${widget.title} (${widget.amount})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('فودافون كاش / Paymob'),
                  selected: isVodafone,
                  onSelected: (_) => setState(() => _gateway = 'vodafone'),
                ),
                ChoiceChip(
                  label: const Text('إنستا باي / Fawry'),
                  selected: !isVodafone,
                  onSelected: (_) => setState(() => _gateway = 'instapay'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _walletPhoneCtrl, decoration: InputDecoration(labelText: isVodafone ? 'رقم المحفظة' : 'عنوان الدفع khadamat@instapay')),
            const SizedBox(height: 10),
            TextField(controller: _walletOtpCtrl, decoration: const InputDecoration(labelText: 'كود التأكيد التجريبي (123456)')),
            const SizedBox(height: 12),
            Text('🎁 ستحصل فوراً على +$cashback كاش باك (10%) وضمان 30 يوماً', style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          icon: const Icon(Icons.verified),
          label: const Text('تأكيد السداد الآن'),
          onPressed: () {
            final ref = '${isVodafone ? "VFC" : "IPN"}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
            Navigator.pop(context);
            widget.onPaymentSuccess(isVodafone ? 'فودافون كاش' : 'إنستا باي', ref);
          },
        ),
      ],
    );
  }
}