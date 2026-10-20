import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/offline_sync_service.dart';

class OfflineOperationsScreen extends StatefulWidget {
  const OfflineOperationsScreen({super.key});

  @override
  State<OfflineOperationsScreen> createState() =>
      _OfflineOperationsScreenState();
}

class _OfflineOperationsScreenState extends State<OfflineOperationsScreen> {
  Future<List<Map<String, dynamic>>>? _operations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _operations ??= context.read<OfflineSyncService>().operations();
  }

  Future<void> _sync() async {
    await context.read<OfflineSyncService>().syncPending();
    if (mounted) {
      setState(
          () => _operations = context.read<OfflineSyncService>().operations());
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<OfflineSyncService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Operaciones sin conexión')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: sync.syncing ? null : _sync,
        icon: sync.syncing
            ? const SizedBox.square(
                dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.sync),
        label: Text(sync.syncing ? 'Sincronizando' : 'Sincronizar'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _operations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(
                child: Text('No hay operaciones locales pendientes.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final status = item['status']?.toString() ?? 'pendiente';
              final color = status == 'confirmada'
                  ? AppTheme.successGreen
                  : (status == 'conflicto' || status == 'rechazada'
                      ? AppTheme.dangerRed
                      : const Color(0xFFF59E0B));
              final id = item['operation_uuid'].toString();
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: .15),
                      child: Icon(
                          item['operation_type'] == 'reserva'
                              ? Icons.bookmark_outline
                              : Icons.point_of_sale,
                          color: color)),
                  title: Text(item['operation_type'] == 'reserva'
                      ? 'Reserva provisional'
                      : 'Venta de contado'),
                  subtitle: Text(
                      'Comprobante ${id.substring(0, 8).toUpperCase()}\n${item['reason'] ?? 'Pendiente de validación central'}'),
                  isThreeLine: true,
                  trailing: Text(status.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
