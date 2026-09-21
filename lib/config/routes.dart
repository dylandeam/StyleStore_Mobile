import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/account/change_password_screen.dart';
import '../screens/account/profile_screen.dart';
import '../screens/catalog/catalog_screen.dart';
import '../screens/catalog/vestidor_virtual_screen.dart';
import '../models/producto.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String changePassword = '/change-password';
  static const String profile = '/profile';
  static const String catalog = '/catalog';
  static const String vestidorVirtual = '/vestidor-virtual';

  static Map<String, WidgetBuilder> get routes => {
        login: (context) => const LoginScreen(),
        register: (context) => const RegisterScreen(),
        home: (context) => const HomeScreen(),
        changePassword: (context) => const ChangePasswordScreen(),
        profile: (context) => const ProfileScreen(),
        catalog: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final tab = (args is int) ? args : 0;
          return CatalogScreen(initialTab: tab);
        },
        vestidorVirtual: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final prod = (args is Producto) ? args : null;
          return VestidorVirtualScreen(initialProduct: prod);
        },
      };
}
