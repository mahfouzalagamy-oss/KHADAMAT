import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_state_service.dart';
import '../../core/services/auth_session.dart';

class CustomerRequestHistory extends StatefulWidget {
  const CustomerRequestHistory({super.key, required this.session});

  final AuthSession session;

  @override
  State<CustomerRequestHistory> createState() => _CustomerRequestHistoryState();
}

class _CustomerRequestHistoryState extends State<CustomerRequestHistory> {
  late Future<List<Map<String, dynamic>>> _requests;
  late String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = widget.session.userId;
    _requests = _load();
    widget.session.addListener(_onSessionChange);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChange);
    super.dispose();
  }

  void _onSessionChange() {
    final userId = widget.session.userId;
    if (_userId == userId) return;
    setState(() {
      _userId = userId;
      _requests = _load();
    });
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final client = widget.session.authenticatedClient;
    if (client == null) return [];
    return client
        .from('khadamat_service_requests')
        .select('id,service_code,district,status,created_at')
        .order('created_at')
        .limit(100);
  }

  @override
  Widget build(BuildContext context) {
    const statuses = {
      'submitted': 'تم الإرسال',
      'booked': 'تم الحجز',
      'in_progress': 'قيد التنفيذ',
      'completed': 'مكتمل',
      'cancelled': 'ملغى',
    };
    final names = {
      for (final service in AppStateService.instance.services)
        service.id: service.name,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي'),
        actions: [
          if (_userId != null)
            IconButton(
              tooltip: 'تحديث الطلبات',
              onPressed: () => setState(() => _requests = _load()),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _userId == null
          ? Center(
              child: FilledButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                child: const Text('سجّل الدخول لعرض طلباتك'),
              ),
            )
          : FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(_userId),
              future: _requests,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _requests = _load()),
                      child: const Text('تعذّر تحميل الطلبات. حاول مرة أخرى'),
                    ),
                  );
                }
                final requests = snapshot.data ?? [];
                if (requests.isEmpty) {
                  return const Center(child: Text('لم ترسل طلبات بعد.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title:
                            Text(names[request['service_code']] ?? 'طلب خدمة'),
                        subtitle: Text(request['district'] as String),
                        trailing: Text(
                            statuses[request['status']] ?? 'الحالة غير متاحة'),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
