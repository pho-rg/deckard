import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/generated/app_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'providers/locale_provider.dart';
import 'services/api_service.dart';

/// Clé de navigation globale : permet de rediriger vers le login depuis
/// n'importe où (ex. handler 401) sans BuildContext.
final navigatorKey = GlobalKey<NavigatorState>();

bool _handlingUnauthorized = false;

void main() {
  // Token expiré/invalide (401) → purge la session et renvoie au login.
  ApiService.onUnauthorized = () async {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    await AuthService.clearLocalSession();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    _handlingUnauthorized = false;
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const DeckardApp(),
    ),
  );
}

class DeckardApp extends StatelessWidget {
  const DeckardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      title: 'Deckard',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
      ],
      home: const AuthGate(),
    );
  }
}

/// Vérifie le token au démarrage.
/// → token trouvé : MainNavigation directement
/// → pas de token : LoginScreen (accepte n'importe quels identifiants pour l'instant)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.tryRestoreToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final isLoggedIn = snapshot.data ?? false;
        return isLoggedIn ? const MainNavigation() : const LoginScreen();
      },
    );
  }
}
