import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/routes/app_routes.dart';
import 'core/services/app_state_service.dart';
import 'core/services/auth_session.dart';
import 'core/theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  SupabaseClient? client;
  if (url.isNotEmpty && key.isNotEmpty) {
    final supabase = await Supabase.initialize(url: url, anonKey: key);
    client = supabase.client;
  }
  runApp(KhadamatOfficialApp(session: AuthSession(client)));
}

class KhadamatOfficialApp extends StatelessWidget {
  const KhadamatOfficialApp({super.key, required this.session});

  final AuthSession session;

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
          onGenerateRoute: (settings) =>
              AppRoutes.onGenerateRoute(settings, session),
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AuthSessionScope(
                session: session,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        );
      },
    );
  }
}
