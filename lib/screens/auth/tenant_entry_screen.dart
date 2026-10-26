import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../services/tenant_portal_service.dart';

class TenantEntryScreen extends StatefulWidget {
  const TenantEntryScreen({super.key});

  @override
  State<TenantEntryScreen> createState() => _TenantEntryScreenState();
}

class _TenantEntryScreenState extends State<TenantEntryScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final selected = await context
        .read<TenantPortalService>()
        .selectByCode(_codeController.text);
    if (selected && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final portal = context.watch<TenantPortalService>();
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.storefront_rounded,
                      size: 78, color: colors.primary),
                  const SizedBox(height: 20),
                  Text(
                    'Encuentra tu tienda',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Ingresa el código que te compartió la tienda. Solo verás su catálogo, promociones e identidad.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppTheme.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _codeController,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    onSubmitted: (_) => portal.loading ? null : _continue(),
                    decoration: const InputDecoration(
                      labelText: 'Código o enlace de tienda',
                      hintText: 'Ej.: varones o …/t/varones/login',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                  ),
                  if (portal.error != null) ...[
                    const SizedBox(height: 12),
                    Text(portal.error!,
                        style: const TextStyle(color: AppTheme.dangerRed)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: portal.loading ? null : _continue,
                    icon: portal.loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                        portal.loading ? 'Validando…' : 'Entrar a la tienda'),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderGlass),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.privacy_tip_outlined, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tu código evita mezclar tiendas competidoras. Si ya tienes cuenta en más de una, podrás cambiar entre ellas después de iniciar sesión.',
                            style: TextStyle(fontSize: 12.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
