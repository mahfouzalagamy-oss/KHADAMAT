import 'package:flutter/material.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/theme.dart';

class SparePartsCatalogModal extends StatefulWidget {
  final String? orderIdForQuote;
  const SparePartsCatalogModal({super.key, this.orderIdForQuote});

  static void show(BuildContext context, {String? orderIdForQuote}) {
    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SparePartsCatalogModal(orderIdForQuote: orderIdForQuote),
      ),
    );
  }

  @override
  State<SparePartsCatalogModal> createState() => _SparePartsCatalogModalState();
}

class _SparePartsCatalogModalState extends State<SparePartsCatalogModal> {
  String _selectedCat = 'الكل';

  @override
  Widget build(BuildContext context) {
    final state = AppStateService.instance;
    final cats = ['الكل', 'تكييف وتبريد', 'سباكة', 'كهرباء', 'أجهزة منزلية'];
    final parts = state.sparePartsCatalog.where((p) => _selectedCat == 'الكل' || p.category == _selectedCat).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.verified_outlined, color: AppColors.syaanhOrange),
          SizedBox(width: 8),
          Expanded(child: Text('أسعار قطع الغيار الرسمية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: cats.map((c) {
                  final sel = _selectedCat == c;
                  return ChoiceChip(
                    label: Text(c, style: TextStyle(fontSize: 11, color: sel ? Colors.white : AppColors.textPrimary)),
                    selected: sel,
                    selectedColor: AppColors.syaanhOrange,
                    onSelected: (_) => setState(() => _selectedCat = c),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              ...parts.map((p) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('${p.brand} • ضمان ${p.warrantyMonths} شهور', style: const TextStyle(fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${p.officialPrice} ج.م', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.customerPrimary)),
                          if (widget.orderIdForQuote != null) ...[
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                state.addOfficialSparePartToOrder(widget.orderIdForQuote!, p);
                                Navigator.pop(context);
                              },
                              child: const Text('إضافة', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
    );
  }
}