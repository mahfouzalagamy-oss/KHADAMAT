import 'package:flutter/material.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/theme.dart';
import '../models/app_models.dart';

class AiSmartDiagnosisModal extends StatefulWidget {
  const AiSmartDiagnosisModal({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: AiSmartDiagnosisModal(),
      ),
    );
  }

  @override
  State<AiSmartDiagnosisModal> createState() => _AiSmartDiagnosisModalState();
}

class _AiSmartDiagnosisModalState extends State<AiSmartDiagnosisModal> {
  final _descCtrl = TextEditingController(text: 'ضعف تبريد التكييف مع صوت طنين');
  String _selectedSound = 'طنين كباس التكييف';
  bool _isAnalyzing = false;
  AiDiagnosisResultModel? _result;

  final List<String> _sounds = const [
    'طنين كباس التكييف',
    'تقطيع مضخة المياه',
    'شرز لوحة الكهرباء',
    'اهتزاز الغسالة',
  ];

  Future<void> _analyzeNow() async {
    setState(() => _isAnalyzing = true);
    final res = await AppStateService.instance.runSmartAiDiagnosis(
      descriptionText: _descCtrl.text,
      soundPattern: _selectedSound,
      hasPhoto: true,
    );
    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _result = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, color: AppColors.syaanhOrange),
          SizedBox(width: 8),
          Expanded(child: Text('التشخيص الذكي AI', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'وصف العطل باختصار', prefixIcon: Icon(Icons.edit_note)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _sounds.map((s) {
                  final sel = _selectedSound == s;
                  return ChoiceChip(
                    label: Text(s, style: TextStyle(fontSize: 11, color: sel ? Colors.white : AppColors.textPrimary)),
                    selected: sel,
                    selectedColor: AppColors.customerPrimary,
                    onSelected: (_) => setState(() => _selectedSound = s),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.bolt),
                label: Text(_isAnalyzing ? 'جاري التحليل...' : 'فحص وتحديد التكلفة'),
                onPressed: _isAnalyzing ? null : _analyzeNow,
              ),
              if (_result != null) ...[
                const Divider(height: 22),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_result!.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(_result!.technicalCause, style: const TextStyle(fontSize: 12)),
                      const Divider(),
                      ..._result!.suggestedParts.map((p) => Text('• ${p.name}: ${p.officialPrice}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.customerPrimary),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRoutes.createOrder, arguments: {'service': _result!.recommendedService});
                        },
                        child: Text('حجز فني (${_result!.recommendedService}) الآن'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
    );
  }
}