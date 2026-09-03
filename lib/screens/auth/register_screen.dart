import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cuenta creada exitosamente! Ahora puedes iniciar sesión.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x1AEC4899),
                          border: Border.all(color: const Color(0x4DEC4899)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stars, color: AppTheme.accentPink, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'StyleStore Auth',
                              style: TextStyle(
                                color: Color(0xFFF472B6),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Header
                    const Text(
                      'Crear Cuenta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Regístrate para comenzar a utilizar StyleStore',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Error message
                    if (authService.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x1AEF4444),
                          border: Border.all(color: const Color(0x4DEF4444)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                authService.errorMessage!,
                                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo',
                        prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted),
                        hintText: 'Juan Pérez',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 2) {
                          return 'El nombre debe tener al menos 2 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted),
                        hintText: 'ejemplo@stylestore.com',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa tu correo';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Correo electrónico no válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textMuted),
                        hintText: 'Mínimo 8 caracteres',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppTheme.textMuted,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 8) {
                          return 'La contraseña debe tener al menos 8 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: authService.status == AuthStatus.loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentIndigo,
                      ),
                      child: authService.status == AuthStatus.loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Registrarme'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿Ya tienes una cuenta? ',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, AppRoutes.login);
                          },
                          child: const Text(
                            'Inicia sesión',
                            style: TextStyle(
                              color: AppTheme.accentIndigo,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
