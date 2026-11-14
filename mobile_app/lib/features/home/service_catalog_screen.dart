import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_state_service.dart';
import '../../core/services/auth_session.dart';

class ServiceCatalogScreen extends StatelessWidget {
  const ServiceCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionScope.of(context);
    final services = AppStateService.instance.services;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('خدمات KHADAMAT'),
        actions: [
          IconButton(
            tooltip: 'طلباتي',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.customerRequests),
          ),
          IconButton(
            tooltip: session.isSignedIn ? 'حسابي' : 'تسجيل الدخول',
            icon:
                Icon(session.isSignedIn ? Icons.person : Icons.person_outline),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 20),
                    SizedBox(width: 6),
                    Text('المنصورة، الدقهلية'),
                  ],
                ),
                const SizedBox(height: 16),
                Text('محتاج خدمة إيه؟', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('اختَر الخدمة وحدّد المشكلة والمكان والموعد.'),
                const SizedBox(height: 20),
                for (final service in services)
                  Card(
                    child: ListTile(
                      leading: Icon(service.icon, color: service.color),
                      title: Text(service.name),
                      subtitle: Text(service.subtitle),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.createOrder,
                        arguments: {'serviceCode': service.id},
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
