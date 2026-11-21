import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/profile_service.dart';
import 'core/theme.dart';
import 'screens/auth_screen.dart';
import 'screens/family_setup_screen.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );
  runApp(const MomOSApp());
}

class MomOSApp extends StatelessWidget {
  const MomOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AuthGate(),
    );
  }
}

/// Routes to sign in, family setup, or the app depending on state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supa.auth.onAuthStateChange,
      builder: (context, _) {
        if (supa.auth.currentSession == null) return const AuthScreen();
        return const _ProfileGate();
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate();
  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Future<Profile?> _future = ProfileService.me();

  void _reload() => setState(() => _future = ProfileService.me());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Profile?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final p = snap.data;
        if (p == null) {
          return Scaffold(
            body: Center(
              child: TextButton(onPressed: _reload, child: const Text('Retry')),
            ),
          );
        }
        if (p.familyId == null) return FamilySetupScreen(onDone: _reload);
        return HomeShell(profile: p, onProfileChanged: _reload);
      },
    );
  }
}
