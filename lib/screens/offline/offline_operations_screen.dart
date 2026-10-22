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

  Future<void> _purgeResolved() async {
    final count = await context.read<OfflineSyncService>().purgeResolved();
    if (!mounted) return;
    setState(
        () => _operations = context.read<OfflineSyncService>().operations());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(count == 0
          ? 'No hay operaciones resueltas para purgar.'
          : 'Se purgaron $count operaciones resueltas de la base de datos local.'),
      backgroundColor: AppTheme.successGreen,
    ));
  }

  Future<void> _clearCache() async {
    final count = await context.read<OfflineSyncService>().clearCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Se limpiaron $count registros de caché local (catálogo/sucursales).'),
      backgroundColor: AppTheme.accentIndigo,
    ));
  }

  Future<void> _showDiagnostics() async {
    final syncService = context.read<OfflineSyncService>();
    final diag = await syncService.getDiagnostics();
    Map<String, dynamic>? remoteMetrics;
    if (syncService.isOnline) {
      remoteMetrics = await syncService.fetchRemoteSyncMetrics();
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diagnóstico de Almacenamiento & Sincronización'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ámbito aislado:\n${diag['scope']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Divider(),
              const Text('ALMACENAMIENTO SQLITE (LOCAL):',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppTheme.accentIndigo)),
              const SizedBox(height: 4),
              Text('• Snapshots de catálogo: ${diag['catalogs_count']}'),
              Text('• Sucursales cacheadas: ${diag['branches_count']}'),
              Text('• Clientes locales: ${diag['clients_count']}'),
              Text('• Cola pendiente: ${diag['pending_count']}'),
              Text('• Total en cola local: ${diag['total_operations']}'),
              const Divider(),
              const Text('MÉTRICAS DEL SERVIDOR (CENTRALIZADAS):',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppTheme.accentIndigo)),
              const SizedBox(height: 4),
              if (remoteMetrics != null) ...[
                Text('• Operaciones registradas: ${remoteMetrics['total_operaciones'] ?? 0}'),
                Text('• Confirmadas con éxito: ${remoteMetrics['total_confirmadas'] ?? 0}'),
                Text('• Conflictos detectados: ${remoteMetrics['total_conflictos'] ?? 0}'),
                Text('• Tasa de éxito: ${remoteMetrics['tasa_exito_porcentaje'] ?? 100}%'),
                if (remoteMetrics['reembolsos_asociados'] != null)
                  Text(
                      '• Reembolsos asociados: ${remoteMetrics['reembolsos_asociados']['total_reembolsos']} (Bs ${remoteMetrics['reembolsos_asociados']['monto_total']})'),
              ] else
                const Text('• Sin conexión con el servidor o en modo avión.',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<OfflineSyncService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operaciones sin conexión'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Diagnóstico de almacenamiento',
            onPressed: _showDiagnostics,
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones de limpieza',
            onSelected: (value) {
              if (value == 'purge') _purgeResolved();
              if (value == 'clear_cache') _clearCache();
              if (value == 'diagnostics') _showDiagnostics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'purge',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Purgar resueltas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_cache',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 20),
                    SizedBox(width: 8),
                    Text('Limpiar caché'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
