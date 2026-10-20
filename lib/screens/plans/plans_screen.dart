import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/subscription_plan.dart';
import '../../services/api_service.dart';
import '../../services/plans_service.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  late final PlansService _service;
  List<SubscriptionPlan> _plans = const [];
  Map<String, dynamic>? _contract;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service = PlansService(context.read<ApiService>());
    if (_loading && _plans.isEmpty) _load();
  }

  Future<void> _load() async {
    try {
      final results =
          await Future.wait([_service.getPlans(), _service.getMyContract()]);
      if (!mounted) return;
      setState(() {
        _plans = results[0] as List<SubscriptionPlan>;
        _contract = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _contractPlan(SubscriptionPlan plan) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contratar ${plan.name}'),
        content: Text(
            'El precio mensual será ${plan.currency} ${plan.price.toStringAsFixed(2)}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      final contract = await _service.contract(plan.code);
      if (!mounted) return;
      setState(() => _contract = contract);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plan ${plan.name} contratado.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Color _colorFor(SubscriptionPlan plan) {
    final hex = plan.style['color_primario']?.toString().replaceFirst('#', '');
    if (hex != null && hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    if (plan.code == 'profesional') return const Color(0xFF7C3AED);
    if (plan.code == 'basico') return const Color(0xFF0F766E);
    return const Color(0xFFB45309);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Planes de Suscripción')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        const Text('Una experiencia a tu medida',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 8),
                        const Text(
                            'Compara las tres opciones configuradas por tu tienda.',
                            style: TextStyle(color: AppTheme.textSecondary)),
                        if (_contract != null) ...[
                          const SizedBox(height: 16),
                          Card(
                              color: AppTheme.accentIndigo,
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                      'Plan activo: ${_contract!['plan_nombre']}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)))),
                        ],
                        const SizedBox(height: 14),
                        ..._plans.map(_buildPlanCard),
                      ],
                    ),
                  ),
      );

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final color = _colorFor(plan);
    final current = _contract?['plan_codigo'] == plan.code;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
              color: color.withValues(alpha: .45),
              width: plan.code == 'profesional' ? 2 : 1)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(plan.code.toUpperCase(),
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(plan.name,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(plan.description ?? 'Contenido configurable por tu tienda.',
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 18),
          Text('${plan.currency} ${plan.price.toStringAsFixed(2)} / mes',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 12),
          Text(plan.maxBranches == null
              ? 'Alcance configurable'
              : 'Hasta ${plan.maxBranches} sucursales'),
          Text(plan.generativeAi
              ? 'IA generativa incluida'
              : 'Sin IA generativa'),
          const SizedBox(height: 12),
          ...plan.benefits.map((benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(Icons.check_circle, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(benefit))
              ]))),
          if (plan.benefits.isEmpty)
            const Text('Beneficios pendientes de configuración.',
                style: TextStyle(
                    color: AppTheme.textMuted, fontStyle: FontStyle.italic)),
          const SizedBox(height: 18),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: current ? null : () => _contractPlan(plan),
                  style: FilledButton.styleFrom(backgroundColor: color),
                  child: Text(current ? 'Plan actual' : 'Contratar plan'))),
        ]),
      ),
    );
  }
}
