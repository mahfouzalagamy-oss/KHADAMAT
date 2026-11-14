import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/auth_session.dart';
import '../../shared/models/app_models.dart';
import 'customer_request_draft.dart';

class CustomerRequestScreen extends StatefulWidget {
  const CustomerRequestScreen({super.key, required this.service});

  final ServiceItemModel service;

  @override
  State<CustomerRequestScreen> createState() => _CustomerRequestScreenState();
}

class _CustomerRequestScreenState extends State<CustomerRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _district = TextEditingController();
  final _address = TextEditingController();
  DateTime? _appointment;
  int _step = 0;
  bool _submitting = false;
  String? _submissionId;
  String? _submitterId;
  String? _error;
  String? _requestId;
  late final CustomerRequestDraftStore _draft;
  bool _draftInitialized = false;
  bool _loadingDraft = true;
  bool _savingDraft = false;
  CustomerRequestDraftStore? _submissionDraft;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = AuthSessionScope.of(context);
    if (_draftInitialized) return;
    _draftInitialized = true;
    _draft = CustomerRequestDraftStore(widget.service.id, session.userId);
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    try {
      final data = await _draft.read();
      if (!mounted || data == null) return;
      _description.text = data['description'] as String? ?? '';
      _district.text = data['district'] as String? ?? '';
      _address.text = data['address'] as String? ?? '';
      final appointment =
          DateTime.tryParse(data['appointment'] as String? ?? '');
      _submissionId = data['submissionId'] as String?;
      _submitterId = data['submitterId'] as String?;
      _appointment = _submissionId != null ||
              (appointment?.isAfter(DateTime.now()) ?? false)
          ? appointment?.toLocal()
          : null;
      if (_submissionId != null) {
        _step = 2;
        _submissionDraft = _draft;
      }
    } on Exception {
      if (mounted) _error = 'تعذّر استعادة المسودة.';
    } finally {
      if (mounted) setState(() => _loadingDraft = false);
    }
  }

  Map<String, Object?> _draftData() => {
        'description': _description.text,
        'district': _district.text,
        'address': _address.text,
        'appointment': _appointment?.toUtc().toIso8601String(),
        'submissionId': _submissionId,
        'submitterId': _submitterId,
      };

  Future<void> _saveDraft() async {
    setState(() => _savingDraft = true);
    try {
      await _draft.save(_draftData());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ المسودة على هذا الجهاز.')),
        );
      }
    } on Exception {
      if (mounted) setState(() => _error = 'تعذّر حفظ المسودة.');
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _district.dispose();
    _address.dispose();
    super.dispose();
  }

  String _newSubmissionId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _goTo(int step) {
    setState(() {
      _step = step;
      _error = null;
    });
  }

  Future<void> _pickAppointment() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      initialDate: _appointment ?? now,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _appointment == null
          ? TimeOfDay.now()
          : TimeOfDay.fromDateTime(_appointment!),
    );
    if (time == null || !mounted) return;
    final date = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    setState(() {
      if (date.isAfter(DateTime.now())) {
        _appointment = date;
        _error = null;
      } else {
        _error = 'اختَر موعدًا في المستقبل.';
      }
    });
  }

  Future<void> _submit() async {
    final session = AuthSessionScope.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (!session.isSignedIn) {
        await Navigator.pushNamed(context, AppRoutes.login);
        if (!mounted || !session.isSignedIn) return;
      }
      final userId = session.userId!;
      if (_submitterId != null && _submitterId != userId) {
        setState(() => _error = 'تغيّر الحساب. ابدأ طلبًا جديدًا من الرئيسية.');
        return;
      }
      _submitterId = userId;
      _submissionId ??= _newSubmissionId();
      _submissionDraft ??= CustomerRequestDraftStore(widget.service.id, userId);
      await _submissionDraft!.save(_draftData());
      if (!mounted || session.userId != userId) return;
      final id = await session.authenticatedClient!.rpc<String>(
        'khadamat_submit_request',
        params: {
          'p_submission_id': _submissionId,
          'p_service_code': widget.service.id,
          'p_district': _district.text.trim(),
          'p_address': _address.text.trim(),
          'p_description': _description.text.trim(),
          'p_preferred_at': _appointment?.toUtc().toIso8601String(),
        },
      );
      if (mounted && session.userId == userId) {
        setState(() => _requestId = id);
      }
      try {
        await _submissionDraft!.clear();
        await _draft.clear();
      } on Exception {
        // A saved retry still uses the same idempotency key.
      }
    } on Exception {
      if (mounted) {
        setState(() =>
            _error = 'تعذّر تأكيد الحفظ. حاول إرسال الطلب نفسه مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _appointmentLabel(BuildContext context) {
    final date = _appointment;
    if (date == null) return 'أقرب موعد متاح';
    final local = MaterialLocalizations.of(context);
    return '${local.formatShortDate(date)} · ${local.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }

  @override
  Widget build(BuildContext context) {
    const steps = ['التفاصيل', 'المكان والموعد', 'المراجعة'];
    final theme = Theme.of(context);
    final session = AuthSessionScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('طلب ${widget.service.name}')),
      body: _loadingDraft
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: _requestId != null
                        ? [
                            const Icon(Icons.check_circle_outline, size: 56),
                            const SizedBox(height: 16),
                            Text('تم إرسال طلبك',
                                style: theme.textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            SelectableText(_requestId!,
                                textDirection: TextDirection.ltr),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.customerRequests,
                              ),
                              child: const Text('عرض طلباتي'),
                            ),
                          ]
                        : [
                            Row(
                              children: [
                                for (var i = 0; i < steps.length; i++)
                                  Expanded(
                                    child: Column(
                                      children: [
                                        CircleAvatar(
                                          radius: 15,
                                          backgroundColor: i == _step
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme
                                                  .surfaceContainerHighest,
                                          foregroundColor: i == _step
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurface,
                                          child: Text('${i + 1}'),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(steps[i],
                                            textAlign: TextAlign.center),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Form(
                              key: _form,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_step == 0) ...[
                                    Text('إيه المشكلة؟',
                                        style: theme.textTheme.headlineSmall),
                                    const SizedBox(height: 12),
                                    _field(_description, 'وصف المشكلة', 2000,
                                        lines: 4),
                                  ],
                                  if (_step == 1) ...[
                                    Text('فين ومتى؟',
                                        style: theme.textTheme.headlineSmall),
                                    const SizedBox(height: 12),
                                    const Text('المنصورة، الدقهلية'),
                                    const SizedBox(height: 12),
                                    _field(_district, 'المنطقة', 100),
                                    const SizedBox(height: 12),
                                    _field(
                                        _address, 'الشارع ورقم العمارة', 300),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: _pickAppointment,
                                      icon: const Icon(
                                          Icons.calendar_today_outlined),
                                      label: Text(_appointment == null
                                          ? 'اختيار موعد (اختياري)'
                                          : _appointmentLabel(context)),
                                    ),
                                    if (_appointment != null)
                                      TextButton(
                                        onPressed: () => setState(() {
                                          _appointment = null;
                                          _error = null;
                                        }),
                                        child: const Text('أقرب موعد متاح'),
                                      ),
                                  ],
                                  if (_step == 2) ...[
                                    Text('راجع طلبك',
                                        style: theme.textTheme.headlineSmall),
                                    const SizedBox(height: 12),
                                    Card(
                                      child: Column(
                                        children: [
                                          ListTile(
                                              title: const Text('الخدمة'),
                                              subtitle:
                                                  Text(widget.service.name)),
                                          ListTile(
                                              title: const Text('المشكلة'),
                                              subtitle: Text(
                                                  _description.text.trim())),
                                          ListTile(
                                              title: const Text('المكان'),
                                              subtitle: Text(
                                                  '${_district.text.trim()}، ${_address.text.trim()}')),
                                          ListTile(
                                              title:
                                                  const Text('الموعد المفضل'),
                                              subtitle: Text(
                                                  _appointmentLabel(context))),
                                        ],
                                      ),
                                    ),
                                    if (!session.isConfigured)
                                      const Text(
                                          'إرسال الطلب متاح عند تهيئة الاتصال ببيئة الاختبار.'),
                                  ],
                                ],
                              ),
                            ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(_error!,
                                    style: TextStyle(
                                        color: theme.colorScheme.error)),
                              ),
                            const SizedBox(height: 20),
                            if (_submitting) const LinearProgressIndicator(),
                            FilledButton(
                              onPressed: _submitting ||
                                      _savingDraft ||
                                      (_step == 2 && !session.isConfigured)
                                  ? null
                                  : _step == 2
                                      ? _submit
                                      : () {
                                          if (_form.currentState!.validate()) {
                                            _goTo(_step + 1);
                                          }
                                        },
                              child: Text(_step == 0
                                  ? 'متابعة'
                                  : _step == 1
                                      ? 'مراجعة الطلب'
                                      : session.isSignedIn
                                          ? 'إرسال الطلب'
                                          : 'متابعة برقم الهاتف'),
                            ),
                            if (_submissionId == null)
                              OutlinedButton(
                                onPressed: _savingDraft || _submitting
                                    ? null
                                    : _saveDraft,
                                child: const Text('حفظ كمسودة'),
                              ),
                            if (_step > 0 && _submissionId == null)
                              TextButton(
                                onPressed:
                                    _submitting ? null : () => _goTo(_step - 1),
                                child: const Text('الرجوع للتعديل'),
                              ),
                          ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _field(TextEditingController controller, String label, int limit,
      {int lines = 1}) {
    return TextFormField(
      controller: controller,
      maxLength: limit,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب.' : null,
    );
  }
}
