import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import '../../core/services/app_state_service.dart';
import '../../core/services/auth_session.dart';

class ServiceCatalogScreen extends StatefulWidget {
  const ServiceCatalogScreen({super.key});

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen> {
  String _query = '';

  String _searchKey(String value) => value
      .trim()
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp('[ًٌٍَُِّْـ]'), '');

  @override
  Widget build(BuildContext context) {
    final session = AuthSessionScope.of(context);
    final services = AppStateService.instance.services.where(
      (service) =>
          _searchKey('${service.name} ${service.subtitle}').contains(_query),
    );
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accountLabel = session.isSignedIn ? 'حسابي' : 'تسجيل الدخول';

    return Scaffold(
      appBar: AppBar(
        title: const Text('خدمات KHADAMAT'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, AppRoutes.customerRequests);
          } else if (index == 2) {
            Navigator.pushNamed(context, AppRoutes.login);
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'طلباتي',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: accountLabel,
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
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: colors.tertiary,
                    ),
                    const SizedBox(width: 6),
                    const Flexible(child: Text('المنصورة، الدقهلية')),
                  ],
                ),
                const SizedBox(height: 16),
                Text('محتاج خدمة إيه؟', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('اختَر الخدمة وحدّد المشكلة والمكان والموعد.'),
                const SizedBox(height: 20),
                TextField(
                  textInputAction: TextInputAction.search,
                  onChanged: (value) =>
                      setState(() => _query = _searchKey(value)),
                  decoration: const InputDecoration(
                    labelText: 'ابحث عن خدمة',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 24),
                Text('الخدمات', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                if (services.isEmpty)
                  const Text('مفيش خدمة مطابقة. جرّب اسم خدمة تاني.')
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final textScale =
                          MediaQuery.textScalerOf(context).scale(14) / 14;
                      final columns =
                          constraints.maxWidth >= 330 && textScale <= 1.25
                              ? 3
                              : 2;
                      return GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          mainAxisExtent: 90 + 28 * textScale,
                        ),
                        children: [
                          for (final service in services)
                            Card(
                              margin: EdgeInsets.zero,
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.createOrder,
                                  arguments: {'serviceCode': service.id},
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: service.color
                                            .withValues(alpha: .12),
                                        child: Icon(
                                          service.icon,
                                          color: service.color,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        service.name,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
