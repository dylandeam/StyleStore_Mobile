import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/routes.dart';
import 'config/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/catalog_service.dart';
import 'services/proximamente_service.dart';
import 'services/cart_service.dart';
import 'services/order_service.dart';
import 'services/storage_service.dart';
import 'services/local_database_service.dart';
import 'services/offline_sync_service.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotificationService.initializeFirebase();
  runApp(const StyleStoreApp());
}

class StyleStoreApp extends StatelessWidget {
  const StyleStoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storageService = StorageService();
    final apiService = ApiService(storageService);
    final localDatabase = LocalDatabaseService();
    final pushNotifications = PushNotificationService.instance;
    pushNotifications.configure(apiService, storageService);

    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<ApiService>.value(value: apiService),
        Provider<LocalDatabaseService>.value(value: localDatabase),
        ChangeNotifierProvider<OfflineSyncService>(
          lazy: false,
          create: (_) =>
              OfflineSyncService(apiService, localDatabase, storageService),
        ),
        ChangeNotifierProvider<AuthService>(
          create: (_) =>
              AuthService(apiService, storageService, pushNotifications),
        ),
        ChangeNotifierProvider<CatalogService>(
          create: (_) =>
              CatalogService(apiService, localDatabase, storageService),
        ),
        ChangeNotifierProvider<ProximamenteService>(
          create: (_) => ProximamenteService(apiService),
        ),
        ChangeNotifierProvider<CartService>(
          create: (_) => CartService(apiService, localDatabase, storageService),
        ),
        ChangeNotifierProvider<OrderService>(
          create: (_) => OrderService(apiService),
        ),
      ],
      child: Consumer<AuthService>(
        builder: (context, authService, _) {
          return MaterialApp(
            title: 'StyleStore Mobile',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            navigatorKey: PushNotificationService.navigatorKey,
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
