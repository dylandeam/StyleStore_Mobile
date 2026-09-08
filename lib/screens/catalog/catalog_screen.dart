import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/producto.dart';
import '../../services/catalog_service.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CatalogService>(context, listen: false).fetchCatalog();
    });
  }

  String? _resolveImageUrl(String? foto) {
    if (foto == null || foto.trim().isEmpty) return null;
    final trimmed = foto.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    const origin = 'https://stylestorebackend-production.up.railway.app';
    return '$origin${trimmed.startsWith('/') ? trimmed : '/$trimmed'}';
  }

  @override
  Widget build(BuildContext context) {
    final catalogService = Provider.of<CatalogService>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: const Text(
          'Catálogo de Moda',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => catalogService.fetchCatalog(),
          ),
        ],
      ),
      body: catalogService.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentIndigo),
            )
          : catalogService.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          catalogService.errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => catalogService.fetchCatalog(),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : catalogService.productos.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay productos disponibles por ahora.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: catalogService.productos.length,
                      itemBuilder: (context, index) {
                        final p = catalogService.productos[index];
                        return _buildProductCard(p);
                      },
                    ),
    );
  }

  Widget _buildProductCard(Producto p) {
    final imageUrl = _resolveImageUrl(p.foto);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderGlass),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1414263D),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen del producto si existe o placeholder estilizado
          if (imageUrl != null)
            SizedBox(
              height: 180,
              width: double.infinity,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(p),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 180,
                    color: const Color(0x0D14263D),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentIndigo),
                    ),
                  );
                },
              ),
            )
          else
            _buildImagePlaceholder(p),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x2014263D),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.codigo,
                        style: const TextStyle(
                          color: Color(0xFF14263D),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'Bs. ${p.precio.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF14263D),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  p.nombre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (p.descripcion != null && p.descripcion!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    p.descripcion!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (p.categoriaNombre != null)
                      _buildTag('📁 ${p.categoriaNombre}', Colors.blueGrey),
                    if (p.temporadaNombre != null)
                      _buildTag('🗓️ ${p.temporadaNombre}', Colors.orangeAccent),
                    _buildTag(
                      '📦 ${p.stockTotal} uds. disponibles',
                      p.stockTotal > 0 ? AppTheme.successGreen : AppTheme.dangerRed,
                    ),
                  ],
                ),
                if (p.colores.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text(
                        'Colores: ',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      Expanded(
                        child: Text(
                          p.colores.join(', '),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(Producto p) {
    return Container(
      height: 140,
      width: double.infinity,
      color: const Color(0x0F14263D),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.checkroom, size: 42, color: Color(0xFFC9A96E)),
            const SizedBox(height: 4),
            Text(
              p.categoriaNombre ?? 'Prenda StyleStore',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
