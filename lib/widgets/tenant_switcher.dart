import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/routes.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/catalog_service.dart';
import '../services/order_service.dart';

class TenantSwitcher extends StatefulWidget {
  const TenantSwitcher({super.key});

  @override
  State<TenantSwitcher> createState() => _TenantSwitcherState();
}

class _TenantSwitcherState extends State<TenantSwitcher> {
  List<Map<String, dynamic>> _tenants = const [];
  int? _selectedId;
  bool _loading = true;
  bool _switching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tenants = await context.read<AuthService>().getTenants();
      if (!mounted) return;
      final current = tenants.where((item) => item['is_current'] == true);
      setState(() {
        _tenants = tenants;
        _selectedId = current.isNotEmpty
            ? int.tryParse(current.first['id'].toString())
            : (tenants.isEmpty
                ? null
                : int.tryParse(tenants.first['id'].toString()));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _select(int empresaId) async {
    if (empresaId == _selectedId || _switching) return;
    setState(() {
      _switching = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().selectTenant(empresaId);
      if (!mounted) return;
      context.read<CartService>().resetTenantState();
      context.read<CatalogService>().resetTenantState();
      context.read<OrderService>().resetTenantState();
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Empresa activa actualizada.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _switching = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    }
    if (_tenants.length < 2 && _error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EMPRESA ACTIVA',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 6),
          if (_error != null)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
              icon: const Icon(Icons.refresh),
              label: Text(_error!),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _selectedId,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.business_outlined),
              ),
              items: _tenants
                  .map((tenant) => DropdownMenuItem<int>(
                        value: int.tryParse(tenant['id'].toString()),
                        child: Text(tenant['nombre'].toString(),
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _switching
                  ? null
                  : (value) {
                      if (value != null) _select(value);
                    },
            ),
          if (_switching) ...[
            const SizedBox(height: 6),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
