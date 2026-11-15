import 'package:flutter/material.dart';
import 'core/routes/app_routes.dart';
import 'core/services/app_state_service.dart';
import 'core/theme/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KhadamatOfficialApp());
}

class KhadamatOfficialApp extends StatelessWidget {
  const KhadamatOfficialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStateService.instance,
      builder: (context, _) {
        final state = AppStateService.instance;
        return MaterialApp(
          title: 'خدمات | KHADAMAT',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(state.currentRole),
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}