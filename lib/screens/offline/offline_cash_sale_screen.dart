import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/local_database_service.dart';
import '../../services/offline_sync_service.dart';
import '../../services/storage_service.dart';

class OfflineCashSaleScreen extends StatefulWidget {
  const OfflineCashSaleScreen({super.key});

  @override
  State<OfflineCashSaleScreen> createState() => _OfflineCashSaleScreenState();
}

class _OfflineCashSaleScreenState extends State<OfflineCashSaleScreen> {
  List<Map<String, dynamic>> _options = [];
  Map<String, dynamic>? _selected;
  int _quantity = 1;
  final _cashController = TextEditingController();
  final _clientController = TextEditingController(text: 'CLI-GENERAL');
  bool _loading = true;
  bool _submitting = false;

  double get _total =>
      (_selected?['precio'] as num? ?? 0).toDouble() * _quantity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final storage = context.read<StorageService>();
    final database = context.read<LocalDatabaseService>();
    final scope = await storage.getOfflineScope();
    final options = await database.stockOptions(scope);
    if (mounted) {
      setState(() {
        _options = options;
        _selected = options.isEmpty ? null : options.first;
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final item = _selected;
    final cash =
        double.tryParse(_cashController.text.replaceAll(',', '.')) ?? 0;
    if (item == null || cash < _total) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Selecciona una prenda e ingresa efectivo suficiente.')));
      return;
    }
    setState(() => _submitting = true);
    final details = [
      {
        'stock_inventario_id': item['stock_inventario_id'],
        'cantidad': _quantity,
        'precio_unitario': item['precio'],
        'subtotal': _total,
        'producto': item['producto'],
        'color': item['color'],
        'talla': item['talla'],
      }
    ];
    final result = await context.read<OfflineSyncService>().submitCashSale(
      payload: {
        'codigo_cliente': _clientController.text.trim().isEmpty
            ? 'CLI-GENERAL'
            : _clientController.text.trim(),
        'sucursal_id': item['sucursal_id'],
        'metodo_pago': 'efectivo',
        'efectivo_recibido': cash,
        'items': [
          {
            'stock_inventario_id': item['stock_inventario_id'],
            'cantidad': _quantity
          }
        ],
      },
      total: _total,
      details: details,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    final receipt = result.queued
        ? ' Comprobante LOCAL-${result.operationUuid.substring(0, 8).toUpperCase()}.'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${result.message}$receipt'),
      backgroundColor: result.confirmed
          ? AppTheme.successGreen
          : (result.queued ? const Color(0xFFB7791F) : AppTheme.dangerRed),
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Venta de contado')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E6),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Text(
                        'Solo efectivo. Sin conexión se emite un comprobante provisional y el stock se valida al sincronizar.'),
                  ),
                  const SizedBox(height: 18),
                  if (_options.isEmpty)
                    const Text(
                        'No hay inventario descargado. Abre el catálogo con conexión antes de usar caja offline.')
                  else ...[
                    DropdownButtonFormField<Map<String, dynamic>>(
                      initialValue: _selected,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Prenda / variante'),
                      items: _options
                          .map((item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                  '${item['producto']} · ${item['color']} · ${item['talla']} (${item['sucursal']})',
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (value) => setState(() {
                        _selected = value;
                        _quantity = 1;
                      }),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      IconButton(
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline)),
                      Text('$_quantity',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                          onPressed: _quantity <
                                  ((_selected?['cantidad'] as num?)?.toInt() ??
                                      1)
                              ? () => setState(() => _quantity++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline)),
                      const Spacer(),
                      Text('Total Bs. ${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ]),
                    TextField(
                        controller: _clientController,
                        decoration: const InputDecoration(
                            labelText: 'Código de cliente')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _cashController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Efectivo recibido (Bs.)')),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: const Icon(Icons.receipt_long),
                        label: Text(_submitting
                            ? 'Registrando…'
                            : 'Cobrar y emitir comprobante')),
                  ],
                ],
              ),
      );

  @override
  void dispose() {
    _cashController.dispose();
    _clientController.dispose();
    super.dispose();
  }
}
