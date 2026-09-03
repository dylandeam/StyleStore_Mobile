import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/routes.dart';
import 'config/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StyleStoreApp());
}

class StyleStoreApp extends StatelessWidget {
  const StyleStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storageService = StorageService();
    final apiService = ApiService(storageService);

    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(apiService, storageService),
        ),
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, _) {
          return MaterialApp(
            title: 'StyleStore Mobile',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            routes: AppRoutes.routes,
            home: _getInitialScreen(authService),
          );
        },
      ),
    );
  }

  Widget _getInitialScreen(AuthService authService) {
    switch (authService.status) {
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.loading:
      case AuthStatus.initial:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: AppTheme.accentIndigo,
            ),
          ),
        );
    }
  }
}
