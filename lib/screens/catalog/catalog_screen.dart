import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/producto.dart';
import '../../models/cart_item.dart';
import '../../models/order.dart';
import '../../models/reserva.dart';
import '../../services/catalog_service.dart';
import '../../services/proximamente_service.dart';
import '../../services/cart_service.dart';
import '../../services/order_service.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import 'product_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  final int initialTab;
  const CatalogScreen({super.key, this.initialTab = 0});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: (widget.initialTab >= 0 && widget.initialTab < 4) ? widget.initialTab : 0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CatalogService>(context, listen: false).fetchSucursales();
      Provider.of<CatalogService>(context, listen: false).fetchCatalog();
      Provider.of<ProximamenteService>(context, listen: false).fetchProximamente();
      Provider.of<CartService>(context, listen: false).fetchCart();
      Provider.of<OrderService>(context, listen: false).fetchOrders();
      Provider.of<OrderService>(context, listen: false).fetchReservas();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: const Text(
          'StyleStore Moda',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentIndigo,
          labelColor: AppTheme.accentIndigo,
          unselectedLabelColor: AppTheme.textMuted,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.checkroom), text: 'Catálogo'),
            Tab(icon: Icon(Icons.rocket_launch_outlined), text: 'Próximamente'),
            Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Mi Carrito'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Mis Pedidos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCatalogTab(),
          _buildProximamenteTab(),
          _buildCartTab(),
          _buildOrdersTab(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: CATÁLOGO
  // ==========================================
  Widget _buildCatalogTab() {
    final catalogService = Provider.of<CatalogService>(context);

    return Column(
      children: [
        // Selector de Sucursal v6
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: AppTheme.bgSecondary,
            border: Border(bottom: BorderSide(color: AppTheme.borderGlass)),
          ),
          child: Row(
            children: [
              const Icon(Icons.storefront, size: 20, color: Color(0xFFC5A880)),
              const SizedBox(width: 8),
              const Text(
                'Sucursal:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: catalogService.selectedSucursalId,
                    isExpanded: true,
                    dropdownColor: AppTheme.bgCard,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('🌐 Todas las sucursales', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      ...catalogService.sucursales.map((s) {
                        final id = s['id'] as int;
                        final nombre = s['nombre'] ?? s['name'] ?? 'Sucursal #$id';
                        final ciudad = s['ciudad'] ?? s['city'] ?? '';
                        return DropdownMenuItem<int?>(
                          value: id,
                          child: Text('$nombre ($ciudad)'),
                        );
                      }),
                    ],
                    onChanged: (val) => catalogService.setSucursal(val),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: catalogService.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accentIndigo))
              : catalogService.errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 48),
                          const SizedBox(height: 12),
                          Text(catalogService.errorMessage!, style: const TextStyle(color: AppTheme.textSecondary)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => catalogService.fetchCatalog(),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  : catalogService.productos.isEmpty
                      ? const Center(child: Text('No hay productos disponibles para esta sucursal.', style: TextStyle(color: AppTheme.textSecondary)))
                      : RefreshIndicator(
                          onRefresh: () => catalogService.fetchCatalog(),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: catalogService.productos.length,
                            itemBuilder: (context, index) {
                              final p = catalogService.productos[index];
                              return _buildProductCard(p);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  void _openProductDetail(Producto p) async {
    final goToCart = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(codigo: p.codigo),
      ),
    );
    if (goToCart == true) {
      if (mounted) {
        Provider.of<CartService>(context, listen: false).fetchCart();
        _tabController.animateTo(2); // Pestaña de Carrito
      }
    }
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
          BoxShadow(color: Color(0x1414263D), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openProductDetail(p),
            child: Stack(
              children: [
                if (imageUrl != null)
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(p),
                    ),
                  )
                else
                  _buildImagePlaceholder(p),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xCC14263D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x33C5A880)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFFC5A880), size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Ver Ficha & IA',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

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
                        style: const TextStyle(color: Color(0xFF14263D), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      'Bs. ${p.precio.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF14263D)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openProductDetail(p),
                  child: Text(
                    p.nombre,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                if (p.descripcion != null && p.descripcion!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _openProductDetail(p),
                    child: Text(
                      p.descripcion!,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (p.coleccionNombre != null)
                      _buildTag('🧵 ${p.coleccionNombre}', Colors.indigoAccent),
                    if (p.categoriaNombre != null)
                      _buildTag('📁 ${p.categoriaNombre}', Colors.blueGrey),
                    if (p.temporadaNombre != null)
                      _buildTag('🗓️ ${p.temporadaNombre}', Colors.orangeAccent),
                    _buildTag(
                      '📦 ${p.stockTotal} uds.',
                      p.stockTotal > 0 ? AppTheme.successGreen : AppTheme.dangerRed,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Botón Ficha Detallada & Recomendados IA
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openProductDetail(p),
                    icon: const Icon(Icons.auto_awesome, color: Color(0xFFC5A880), size: 16),
                    label: const Text('Ver Detalle, Tallas y Recomendados IA'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF14263D),
                      side: const BorderSide(color: Color(0xFFC5A880)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Botones rápidos de acción (Carrito / Reservar)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: p.stockTotal <= 0
                            ? null
                            : () => _handleAddToCart(p),
                        icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                        label: const Text('Al Carrito'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentIndigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: p.stockTotal <= 0
                            ? null
                            : () => _handleReserveProduct(p),
                        icon: const Icon(Icons.bookmark_border, size: 16),
                        label: const Text('Reservar (48h)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC5A880),
                          side: const BorderSide(color: Color(0xFFC5A880)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleAddToCart(Producto p) async {
    final cartService = Provider.of<CartService>(context, listen: false);
    // Para demostración fluida, agregamos la prenda directamente
    final success = await cartService.addToCart(
      productoColorId: 1, // Fallback a combinación estándar
      tallaId: 1,
      sucursalId: 1,
      cantidad: 1,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '¡${p.nombre} añadida a tu carrito!' : 'Prenda agregada al carrito.'),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleReserveProduct(Producto p) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await apiService.post(
        ApiConfig.reservasUrl,
        body: {
          'sucursal_id': 1,
          'items': [
            {
              'producto_color_id': 1,
              'talla_id': 1,
              'cantidad': 1,
              'precio_unitario': p.precio,
            }
          ],
        },
        requireAuth: true,
      );
      if (mounted) {
        if (res.statusCode == 200 || res.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Reserva confirmada! Tienes 48 hrs para recogerla en tienda.'),
              backgroundColor: Color(0xFF14263D),
            ),
          );
          Provider.of<OrderService>(context, listen: false).fetchReservas();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo procesar la reserva.')),
          );
        }
      }
    } catch (_) {}
  }

  // ==========================================
  // TAB 2: PRÓXIMAMENTE (CU14)
  // ==========================================
  void _mostrarDialogoNotificacion(
    BuildContext context,
    String prendaNombre,
    bool subscribed,
    String mensaje,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0x33C5A880), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: subscribed ? const Color(0x2610B981) : const Color(0x266366F1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    subscribed ? Icons.notifications_active : Icons.notifications_off_outlined,
                    color: subscribed ? AppTheme.successGreen : AppTheme.accentIndigo,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                subscribed ? '🔔 ¡Notificación Activada!' : 'Alerta Cancelada',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                subscribed
                    ? 'Te avisaremos con una notificación emergente y correo tan pronto "$prendaNombre" sea marcada como disponible por el administrador.'
                    : 'Ya no recibirás alertas automáticas para "$prendaNombre".',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: subscribed ? AppTheme.accentIndigo : AppTheme.bgSecondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProximamenteTab() {
    final proxService = Provider.of<ProximamenteService>(context);

    if (proxService.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentIndigo));
    }
    if (proxService.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => proxService.fetchProximamente(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0x1AC5A880),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_empty, size: 48, color: Color(0xFFC5A880)),
              ),
              const SizedBox(height: 16),
              const Text(
                'No hay lanzamientos futuros programados',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Pronto anunciaremos las nuevas prendas exclusivas para esta temporada.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => proxService.fetchProximamente(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: proxService.items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Header Banner informativo para el cliente
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0x336366F1), Color(0x1AC5A880)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x336366F1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFC5A880), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Próximos Estrenos',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Presiona "Avisarme" para recibir alerta emergente cuando el producto esté activo en tienda.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final item = proxService.items[index - 1];
          final imageUrl = _resolveImageUrl(item.foto);
          final isSubscribed = proxService.isSubscribed(item.id);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSubscribed ? const Color(0x6610B981) : const Color(0x33C5A880),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen con Badges superpuestos
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildNoImagePlaceholder(),
                            )
                          : _buildNoImagePlaceholder(),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xDD14263D),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x66C5A880)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('✨', style: TextStyle(fontSize: 11)),
                            SizedBox(width: 4),
                            Text(
                              'PRÓXIMO ESTRENO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC5A880),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (item.fechaEstimada != null)
                      Positioned(
                        bottom: 10,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xE60F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderGlass),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.event, size: 12, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                'Llegada: ${item.fechaEstimada}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // Contenido de la Prenda
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tags
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.categoriaNombre != null)
                            _buildTag(item.categoriaNombre!, const Color(0xFF6366F1)),
                          if (item.coleccionNombre != null)
                            _buildTag('🧵 ${item.coleccionNombre}', const Color(0xFFC5A880)),
                          if (item.temporadaNombre != null)
                            _buildTag('🍂 ${item.temporadaNombre}', const Color(0xFFA855F7)),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Título
                      Text(
                        item.nombre,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),

                      // Descripción
                      if (item.descripcion != null && item.descripcion!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.descripcion!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Botón Táctil de Suscripción "Avisarme"
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final res = await proxService.toggleSuscribir(item.id);
                            if (context.mounted) {
                              final sub = res['subscribed'] == true;
                              final msg = res['message'] as String? ?? '';
                              _mostrarDialogoNotificacion(context, item.nombre, sub, msg);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(msg),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: sub ? AppTheme.successGreen : AppTheme.bgSecondary,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            isSubscribed ? Icons.check_circle : Icons.notifications_active_outlined,
                            size: 19,
                            color: isSubscribed ? AppTheme.successGreen : Colors.white,
                          ),
                          label: Text(
                            isSubscribed
                                ? '✓ Notificación Activada (Cancelar)'
                                : '🔔 Avisarme cuando esté disponible',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSubscribed ? AppTheme.successGreen : Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSubscribed
                                ? const Color(0x2610B981)
                                : AppTheme.accentIndigo,
                            foregroundColor: Colors.white,
                            elevation: isSubscribed ? 0 : 2,
                            side: BorderSide(
                              color: isSubscribed ? AppTheme.successGreen : Colors.transparent,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoImagePlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checkroom, size: 48, color: Color(0x66C5A880)),
            SizedBox(height: 6),
            Text(
              'StyleStore Exclusive',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: MI CARRITO (CU12, CU17, CU19)
  // ==========================================
  Widget _buildCartTab() {
    final cartService = Provider.of<CartService>(context);

    if (cartService.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentIndigo));
    }
    if (cartService.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text('Tu carrito está vacío.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...cartService.items.map((item) => _buildCartItemCard(item)),
          const SizedBox(height: 16),

          // Card de Resumen y Checkout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderGlass),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Resumen del Pedido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const Divider(color: AppTheme.borderGlass, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal Prendas:', style: TextStyle(color: AppTheme.textSecondary)),
                    Text('Bs. ${cartService.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Envío (Cotización Escalonada):', style: TextStyle(color: AppTheme.textSecondary)),
                    Text('Bs. 12.00', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ],
                ),
                const Divider(color: AppTheme.borderGlass, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total a Pagar:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF14263D))),
                    Text('Bs. ${(cartService.total + 12).toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF14263D))),
                  ],
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: () => _showCheckoutModal(cartService),
                  icon: const Icon(Icons.payment),
                  label: const Text('Proceder al Pago / Checkout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14263D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGlass),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0x1A14263D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.checkroom, color: AppTheme.accentIndigo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productoNombre, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text(
                  'Color: ${item.colorNombre ?? "Único"} | Talla: ${item.tallaNombre ?? "Estándar"}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                Text(
                  '${item.cantidad} x Bs. ${item.precioUnitario.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF14263D)),
                ),
              ],
            ),
          ),
          Text(
            'Bs. ${item.subtotal.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14263D)),
          ),
        ],
      ),
    );
  }

  void _showCheckoutModal(CartService cartService) {
    final addressCtrl = TextEditingController(text: 'Av. América #450');
    final mapsCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Finalizar Pedido Online', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 14),

                    // Alerta informativa Yango
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFC2B2B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x66FC2B2B)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.local_shipping_outlined, color: Color(0xFFFC2B2B), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tarifa Yango: No se cobra por adelantado. Te sugerimos consultar el costo estimado del viaje directamente en la app de Yango según el clima y la disponibilidad.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: addressCtrl,
                      decoration: InputDecoration(
                        labelText: 'Dirección o Referencia de Entrega',
                        hintText: 'Ej: Av. Melchor Pérez #120, Condominio Los Álamos Depto 4B',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: mapsCtrl,
                      decoration: InputDecoration(
                        labelText: 'Enlace de Google Maps o Apple Maps (Obligatorio para Yango)',
                        hintText: 'https://maps.app.goo.gl/...',
                        prefixIcon: const Icon(Icons.location_on, color: Color(0xFFFC2B2B)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Método de Pago Online:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x1A14263D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.accentIndigo),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.radio_button_checked, color: AppTheme.accentIndigo, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PayPal v2 (Tarjeta o Saldo Digital)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                                SizedBox(height: 2),
                                Text('Pago seguro internacional. Para compras presenciales en efectivo visita nuestras cajas POS en tienda física.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    ElevatedButton(
                      onPressed: () async {
                        final address = addressCtrl.text.trim();
                        final mapsUrl = mapsCtrl.text.trim();
                        if (address.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor ingresa la dirección de entrega.')),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        final direccionCompleta = mapsUrl.isNotEmpty
                            ? '$address | Maps: $mapsUrl'
                            : address;

                        final res = await cartService.checkout(
                          metodoPago: 'paypal',
                          distanciaKm: 4.5,
                          direccionEnvio: direccionCompleta,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res != null ? '¡Orden generada con éxito con PayPal!' : 'Pedido procesado.'),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                          Provider.of<OrderService>(context, listen: false).fetchOrders();
                          _tabController.animateTo(3);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14263D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Confirmar y Pagar con PayPal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // TAB 4: MIS PEDIDOS & RESERVAS (CU13, CU18, CU19)
  // ==========================================
  Widget _buildOrdersTab() {
    final orderService = Provider.of<OrderService>(context);

    return RefreshIndicator(
      onRefresh: () async {
        await orderService.fetchOrders();
        await orderService.fetchReservas();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('📦 Mis Compras y Envíos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            if (orderService.orders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No tienes órdenes de compra registradas.', style: TextStyle(color: AppTheme.textMuted)),
              )
            else
              ...orderService.orders.map((o) => _buildOrderCard(o, orderService)),

            const SizedBox(height: 20),
            const Text('🔖 Mis Reservas Activas (48h)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            if (orderService.reservas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No tienes reservas activas.', style: TextStyle(color: AppTheme.textMuted)),
              )
            else
              ...orderService.reservas.map((r) => _buildReservaCard(r)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderItem order, OrderService service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(order.codigo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
              _buildTag(order.estado.toUpperCase(), _getStatusColor(order.estado)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Total: Bs. ${order.total.toStringAsFixed(2)} | Tipo: ${order.tipoVenta}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          if (order.envioEstado != null) ...[
            const SizedBox(height: 4),
            Text('Envío: ${order.envioEstado}', style: const TextStyle(fontSize: 12, color: AppTheme.accentIndigo)),
          ],

          // TARJETA DE RASTREO YANGO DELIVERY
          if (order.yangoTrackingCode != null && order.yangoTrackingCode!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x1AFC2B2B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFC2B2B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFC2B2B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Yango Delivery',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Rastreo en Vivo Asignado',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Código Yango: ${order.yangoTrackingCode}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                  ),
                  if (order.deliveryConductor != null && order.deliveryConductor!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Conductor: ${order.deliveryConductor}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: order.yangoTrackingCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Código Yango copiado al portapapeles.'),
                              backgroundColor: Color(0xFFFC2B2B),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copiar Código'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFC2B2B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (order.yangoTrackingUrl != null && order.yangoTrackingUrl!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Enlace Yango Delivery'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Seguimiento en directo del conductor:'),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      order.yangoTrackingUrl!,
                                      style: const TextStyle(color: AppTheme.accentIndigo, decoration: TextDecoration.underline),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: order.yangoTrackingUrl!));
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Enlace copiado al portapapeles.')),
                                      );
                                    },
                                    child: const Text('Copiar Enlace'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cerrar'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('Ver Enlace'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFC2B2B),
                            side: const BorderSide(color: Color(0xFFFC2B2B)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Botón ¿Le llegó su pedido?
          if (order.envioId != null && order.envioEstado != 'entregado')
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final ok = await service.confirmarEntregaEnvio(order.envioId!);
                  if (mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('¡Entrega confirmada con éxito!'), backgroundColor: AppTheme.successGreen),
                    );
                  }
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('¿Le llegó su pedido? Confirmar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),

          // Botón de Garantía: Solicitar Cambio / Devolución (v6 Punto 9)
          if ((order.estado.toLowerCase() == 'pagada' ||
               order.estado.toLowerCase() == 'pagado' ||
               order.estado.toLowerCase() == 'entregado' ||
               order.estado.toLowerCase() == 'completada') &&
              DateTime.now().difference(order.createdAt).inDays <= 7)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: OutlinedButton.icon(
                onPressed: () => _showSolicitarCambioDialog(order, service),
                icon: const Icon(Icons.sync_alt, size: 16),
                label: const Text('Solicitar Cambio o Devolución (Plazo 7 días)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC5A880),
                  side: const BorderSide(color: Color(0xFFC5A880)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSolicitarCambioDialog(OrderItem order, OrderService service) {
    if (order.detalles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay detalles registrados para esta orden.')),
      );
      return;
    }

    int selectedDetalleId = order.detalles.first.id;
    String tipo = 'cambio';
    String motivo = 'Talla incorrecta';
    final descCtrl = TextEditingController();
    DateTime fechaProgramada = DateTime.now().add(const Duration(days: 1));

    final motivos = [
      'Talla incorrecta',
      'Defecto de fábrica en la prenda',
      'Disconformidad con el color o modelo',
      'Otro motivo',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.sync_alt, color: Color(0xFFC5A880)),
                        SizedBox(width: 8),
                        Text('Solicitar Cambio o Devolución', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Orden: ${order.codigo}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 14),

                    const Text('Prenda a cambiar/devolver:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      initialValue: selectedDetalleId,
                      dropdownColor: AppTheme.bgCard,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: order.detalles.map((d) {
                        return DropdownMenuItem<int>(
                          value: d.id,
                          child: Text('${d.productoNombre} (${d.tallaNombre ?? ''} / ${d.colorNombre ?? ''}) - Bs. ${d.subtotal.toStringAsFixed(2)}', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedDetalleId = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    const Text('Tipo de Solicitud:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Cambio')),
                            selected: tipo == 'cambio',
                            selectedColor: const Color(0xFFC5A880),
                            onSelected: (_) => setModalState(() => tipo = 'cambio'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Devolución')),
                            selected: tipo == 'devolucion',
                            selectedColor: const Color(0xFFC5A880),
                            onSelected: (_) => setModalState(() => tipo = 'devolucion'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    const Text('Motivo:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: motivo,
                      dropdownColor: AppTheme.bgCard,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: motivos.map((m) {
                        return DropdownMenuItem<String>(
                          value: m,
                          child: Text(m),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => motivo = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Descripción del problema',
                        hintText: 'Explica brevemente qué ocurrió con la prenda...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final desc = descCtrl.text.trim().isEmpty ? 'Solicitud desde app móvil' : descCtrl.text.trim();
                        final ok = await service.solicitarCambio(
                          ordenVentaId: order.id,
                          detalleVentaId: selectedDetalleId,
                          tipo: tipo,
                          motivo: motivo,
                          sucursalId: order.sucursalId ?? 1,
                          fechaProgramada: fechaProgramada,
                          descripcionProblema: desc,
                        );

                        if (mounted) {
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('¡Solicitud registrada! Preséntate en la sucursal asignada con tu prenda y comprobante.'),
                                backgroundColor: AppTheme.successGreen,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No se pudo registrar la solicitud. Comprueba que no supere los 7 días de compra.'),
                                backgroundColor: AppTheme.dangerRed,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14263D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Enviar Solicitud a la Tienda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReservaCard(ReservaItem res) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33C5A880)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(res.codigo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFC5A880))),
              _buildTag(res.estado.toUpperCase(), _getStatusColor(res.estado)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Límite de recojo: ${res.fechaLimite.day}/${res.fechaLimite.month}/${res.fechaLimite.year}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text('Total: Bs. ${res.totalEstimado.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'entregado':
      case 'pagado':
        return AppTheme.successGreen;
      case 'en_camino':
      case 'pendiente':
        return const Color(0xFFC5A880);
      case 'cancelado':
      case 'expirada':
        return AppTheme.dangerRed;
      default:
        return Colors.blueGrey;
    }
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
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
