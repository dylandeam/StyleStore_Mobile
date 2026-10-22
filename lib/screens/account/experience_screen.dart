import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../services/catalog_service.dart';
import '../../services/experience_service.dart';
import '../../services/order_service.dart';

class ExperienceScreen extends StatefulWidget {
  final int? initialOrderId;
  const ExperienceScreen({super.key, this.initialOrderId});

  @override
  State<ExperienceScreen> createState() => _ExperienceScreenState();
}

class _ExperienceScreenState extends State<ExperienceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late ExperienceService _service;
  final _comment = TextEditingController();
  final _description = TextEditingController();
  List<Map<String, dynamic>> _ratings = [];
  List<Map<String, dynamic>> _claims = [];
  bool _loading = true;
  int _score = 5;
  int? _orderId;
  int? _branchId;
  int? _ratingId;
  String _reason = 'atencion';
  DateTime _incidentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _orderId = widget.initialOrderId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    _service =
        ExperienceService(Provider.of<ApiService>(context, listen: false));
    final orders = Provider.of<OrderService>(context, listen: false);
    final catalog = Provider.of<CatalogService>(context, listen: false);
    await Future.wait([orders.fetchOrders(), catalog.fetchSucursales()]);
    if (_branchId == null && catalog.sucursales.isNotEmpty) {
      _branchId = catalog.sucursales.first['id'] as int?;
    }
    try {
      final values = await Future.wait([_service.ratings(), _service.claims()]);
      if (mounted) {
        setState(() {
          _ratings = values[0];
          _claims = values[1];
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        _message(error.toString(), error: true);
      }
    }
  }

  List<OrderItem> get _completedOrders => Provider.of<OrderService>(context)
      .orders
      .where((order) => ['pagada', 'entregada', 'completada']
          .contains(order.estado.toLowerCase()))
      .toList();

  void _message(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message.replaceFirst('Exception: ', '')),
      backgroundColor: error ? AppTheme.dangerRed : AppTheme.successGreen,
    ));
  }

  Future<void> _rate() async {
    if (_orderId == null) {
      _message('Selecciona una compra completada.', error: true);
      return;
    }
    try {
      final saved = await _service.rate(_orderId!, _score, _comment.text);
      setState(() {
        _ratings = [
          saved,
          ..._ratings.where((item) => item['id'] != saved['id'])
        ];
        _ratingId = saved['id'] as int?;
        _branchId = saved['sucursal_id'] as int? ?? _branchId;
      });
      if (saved['sugerir_reclamo'] == true && mounted) {
        final create = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Lamentamos lo sucedido'),
                  content: const Text(
                      'Tu calificación quedó guardada. ¿Deseas registrar un reclamo para que la empresa pueda ayudarte?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Ahora no')),
                    ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Crear reclamo'))
                  ],
                ));
        if (create == true) {
          _tabs.animateTo(1);
          setState(() {});
        }
      } else {
        _message('Gracias por compartir tu experiencia.');
      }
    } catch (error) {
      _message(error.toString(), error: true);
    }
  }

  Future<void> _createClaim() async {
    if (_branchId == null || _description.text.trim().length < 10) {
      _message('Selecciona una sucursal y describe lo sucedido.', error: true);
      return;
    }
    try {
      final saved = await _service.createClaim(
        branchId: _branchId!,
        incidentDate: _incidentDate,
        reason: _reason,
        description: _description.text,
        orderId: _orderId,
        ratingId: _ratingId,
      );
      setState(() {
        _claims.insert(0, saved);
        _description.clear();
        _ratingId = null;
      });
      _message('Reclamo #${saved['id']} registrado correctamente.');
    } catch (error) {
      _message(error.toString(), error: true);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _comment.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Calificaciones y Reclamos'),
            bottom: TabBar(controller: _tabs, tabs: const [
              Tab(icon: Icon(Icons.star), text: 'Calificar'),
              Tab(icon: Icon(Icons.support_agent), text: 'Reclamos')
            ])),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabs, children: [_ratingTab(), _claimTab()]),
      );

  Widget _ratingTab() => ListView(padding: const EdgeInsets.all(16), children: [
        _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Califica el servicio',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _orderDropdown(),
          const SizedBox(height: 12),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  5,
                  (index) => IconButton(
                      onPressed: () => setState(() => _score = index + 1),
                      icon: Icon(
                          index < _score ? Icons.star : Icons.star_border,
                          color: const Color(0xFFD4AF37),
                          size: 34)))),
          TextField(
              controller: _comment,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Comentario opcional',
                  border: OutlineInputBorder())),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: _rate, child: const Text('Guardar calificación')),
        ])),
        const SizedBox(height: 16),
        const Text('Mis calificaciones',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ..._ratings.map((item) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('${item['puntuacion']}★')),
            title: Text('Orden #${item['orden_venta_id']}'),
            subtitle:
                Text(item['comentario']?.toString() ?? 'Sin comentario'))),
      ]);

  Widget _claimTab() {
    final branches = Provider.of<CatalogService>(context).sucursales;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Registrar reclamo',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _orderDropdown(),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
            initialValue: _branchId,
            decoration: const InputDecoration(
                labelText: 'Sucursal', border: OutlineInputBorder()),
            items: branches
                .map((branch) => DropdownMenuItem(
                    value: branch['id'] as int,
                    child: Text(
                        (branch['nombre'] ?? branch['name'] ?? 'Sucursal')
                            .toString())))
                .toList(),
            onChanged: (value) => setState(() => _branchId = value)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(
                labelText: 'Motivo', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'atencion', child: Text('Atención')),
              DropdownMenuItem(value: 'producto', child: Text('Producto')),
              DropdownMenuItem(value: 'entrega', child: Text('Entrega')),
              DropdownMenuItem(value: 'pago', child: Text('Pago')),
              DropdownMenuItem(value: 'otro', child: Text('Otro'))
            ],
            onChanged: (value) => setState(() => _reason = value ?? 'otro')),
        const SizedBox(height: 12),
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha del incidente'),
            subtitle: Text(_incidentDate.toIso8601String().substring(0, 10)),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final value = await showDatePicker(
                  context: context,
                  initialDate: _incidentDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now());
              if (value != null) setState(() => _incidentDate = value);
            }),
        TextField(
            controller: _description,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: '¿Qué sucedió?', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        ElevatedButton(
            onPressed: _createClaim, child: const Text('Enviar reclamo')),
      ])),
      const SizedBox(height: 16),
      const Text('Seguimiento',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ..._claims.map((item) => Card(
          child: ListTile(
              title: Text('Reclamo #${item['id']} · ${item['motivo']}'),
              subtitle: Text(
                  '${item['descripcion']}\nEstado: ${item['estado']}${item['respuesta'] != null ? '\nRespuesta: ${item['respuesta']}' : ''}'),
              isThreeLine: true))),
    ]);
  }

  Widget _orderDropdown() => DropdownButtonFormField<int>(
      initialValue:
          _completedOrders.any((item) => item.id == _orderId) ? _orderId : null,
      decoration: const InputDecoration(
          labelText: 'Compra relacionada', border: OutlineInputBorder()),
      items: _completedOrders
          .map((order) => DropdownMenuItem(
              value: order.id,
              child: Text(
                  'Orden #${order.id} · Bs. ${order.total.toStringAsFixed(2)}')))
          .toList(),
      onChanged: (value) => setState(() {
            _orderId = value;
            for (final order in _completedOrders) {
              if (order.id == value && order.sucursalId != null) {
                _branchId = order.sucursalId;
                break;
              }
            }
          }));
  Widget _card(Widget child) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderGlass)),
      child: child);
}
