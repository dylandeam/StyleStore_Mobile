import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../services/offline_sync_service.dart';

class OfflineConnectivityBanner extends StatelessWidget {
  const OfflineConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<OfflineSyncService>();

    if (!sync.isOnline) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFFB45309), // Amber oscuro
        child: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Sin conexión. Operando con catálogo y cola local protegida.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
            if (sync.pendingCount > 0)
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.offlineOperations),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Cola (${sync.pendingCount})',
                    style: const TextStyle(
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
          ],
        ),
      );
    }

    if (sync.pendingCount > 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppTheme.accentIndigo,
        child: Row(
          children: [
            const Icon(Icons.sync_problem, color: Colors.amberAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${sync.pendingCount} operación(es) pendiente(s) de sincronizar.',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.offlineOperations),
              style: TextButton.styleFrom(
                foregroundColor: Colors.amberAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Ver cola',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      decoration: TextDecoration.underline)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
