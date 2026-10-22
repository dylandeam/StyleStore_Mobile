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
    if (result.queued) {
      final provCode =
          'LOCAL-${result.operationUuid.substring(0, 8).toUpperCase()}';
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Comprobante Provisional',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  provCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFFB45309),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _receiptRow('Estado:', 'PROVISIONAL (OFFLINE)', isBadge: true),
              _receiptRow(
                  'Cliente:',
                  _clientController.text.trim().isEmpty
                      ? 'CLI-GENERAL'
                      : _clientController.text.trim()),
              _receiptRow('Prenda:',
                  '${item['producto']} - ${item['color']} (${item['talla']})'),
              _receiptRow('Cantidad:', '$_quantity un.'),
              _receiptRow('Total a pagar:', 'Bs. ${_total.toStringAsFixed(2)}',
                  isBold: true),
              _receiptRow(
                  'Efectivo recibido:', 'Bs. ${cash.toStringAsFixed(2)}'),
              _receiptRow(
                  'Cambio entregado:', 'Bs. ${(cash - _total).toStringAsFixed(2)}'),
              const Divider(height: 20),
              const Text(
                'ℹ️ Comprobante emitido en modo local SQLite. La verificación autoritativa de stock y consolidación fiscal se completarán automáticamente al recuperar conexión con el servidor.',
                style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    height: 1.3),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _load();
              },
              child: const Text('Aceptar y Finalizar'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message),
        backgroundColor:
            result.confirmed ? AppTheme.successGreen : AppTheme.dangerRed,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  Widget _receiptRow(String label, String value,
      {bool isBold = false, bool isBadge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary)),
          if (isBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309)),
              ),
            )
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
        ],
      ),
    );
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
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield_outlined,
                                color: Color(0xFFB45309), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Límites de Operación Offline (REQ-016)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF92400E),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          '• En modo avión solo se admiten cobros en efectivo en caja POS local.\n'
                          '• Pagos digitales (QR Simple, pasarelas, tarjetas) quedan bloqueados sin conexión.\n'
                          '• Se emite un comprobante provisional LOCAL y el stock se consolida al reconectar.',
                          style: TextStyle(
                              color: Color(0xFF78350F),
                              fontSize: 12,
                              height: 1.35),
                        ),
                      ],
                    ),
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
