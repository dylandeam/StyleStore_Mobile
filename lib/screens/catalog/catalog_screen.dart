import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../../models/producto.dart';
import '../../models/cart_item.dart';
import '../../models/order.dart';
import '../../models/reserva.dart';
import '../../services/catalog_service.dart';
import '../../services/proximamente_service.dart';
import '../../services/cart_service.dart';
import '../../services/order_service.dart';
import 'product_detail_screen.dart';
import 'delivery_tracking_screen.dart';
import 'outfits_screen.dart';
import 'chatbot_screen.dart';

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
      length: 6,
      vsync: this,
      initialIndex: (widget.initialTab >= 0 && widget.initialTab < 6) ? widget.initialTab : 0,
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
            Tab(icon: Icon(Icons.local_offer), text: 'Promociones'),
            Tab(icon: Icon(Icons.style_outlined), text: 'Outfits'),
            Tab(icon: Icon(Icons.rocket_launch_outlined), text: 'Próximamente'),
            Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Mi Carrito'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Mis Pedidos'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatbotScreen(
                onNavigateTab: (tabIndex) {
                  _tabController.animateTo(tabIndex);
                },
              ),
            ),
          );
        },
        backgroundColor: AppTheme.accentIndigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.smart_toy_outlined),
        label: const Text('Asesor IA', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCatalogTab(),
          _buildPromocionesTab(),
          _buildOutfitsTab(),
          _buildProximamenteTab(),
          _buildCartTab(),
          _buildOrdersTab(),
        ],
      ),
    );
  }

  Widget _buildOutfitsTab() {
    final catalogService = Provider.of<CatalogService>(context);
    return OutfitsScreen(availableProducts: catalogService.productos);
  }

  // ==========================================
  // TAB PROMO: PROMOCIONES Y DESCUENTOS
  // ==========================================
  Widget _buildPromocionesTab() {
    final catalogService = Provider.of<CatalogService>(context);
    final promos = catalogService.productos.where((p) => p.enPromocion).toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF14263D), Color(0xFF2A1015)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE63946),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '🔥 OFERTAS EXCLUSIVAS',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Descuentos de Temporada',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                '${promos.length} prendas con precios reducidos y promociones activas',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: catalogService.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.accentIndigo))
              : promos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_offer_outlined, color: Colors.grey, size: 54),
                          const SizedBox(height: 12),
                          const Text(
                            'No hay promociones activas en este momento',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Visita el catálogo general para explorar todas nuestras prendas.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => catalogService.fetchCatalog(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: promos.length,
                        itemBuilder: (context, index) {
                          return _buildProductCard(promos[index]);
                        },
                      ),
                    ),
        ),
      ],
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
                if (p.enPromocion)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE63946), Color(0xFFD62828)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Color(0x66E63946), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_offer, color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '${p.porcentajeDescuento}% OFF',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
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
                    if (p.enPromocion && p.precioDescuento != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Bs. ${p.precio.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Bs. ${p.precioDescuento!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE63946),
                            ),
                          ),
                        ],
                      )
                    else
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
                if (p.enPromocion && p.tituloPromocion != null && p.tituloPromocion!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEAEA),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0x40D62828)),
                    ),
                    child: Text(
                      '✨ ${p.tituloPromocion}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD62828),
                      ),
                    ),
                  ),
                ],
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

  void _handleAddToCart(Producto p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(codigo: p.codigo),
      ),
    );
  }

  void _handleReserveProduct(Producto p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(codigo: p.codigo),
      ),
    );
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
                if (cartService.items.isNotEmpty && cartService.items.first.sucursalNombre != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Despacho desde:', style: TextStyle(color: AppTheme.textSecondary)),
                      Text(
                        cartService.items.first.sucursalNombre!,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentIndigo),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal Prendas:', style: TextStyle(color: AppTheme.textSecondary)),
                    Text('Bs. ${cartService.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Delivery StyleStore (5Bs + 0.6Bs/km):', style: TextStyle(color: AppTheme.textSecondary)),
                    Text('Bs. ${(5.0 + (4.5 * 0.60)).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ],
                ),
                const Divider(color: AppTheme.borderGlass, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total a Pagar:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF14263D))),
                    Text('Bs. ${(cartService.total + 5.0 + (4.5 * 0.60)).toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF14263D))),
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
                if (item.sucursalNombre != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '📍 ${item.sucursalNombre}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentIndigo),
                    ),
                  ),
                const SizedBox(height: 2),
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

  Map<String, double>? _extraerCoordsMaps(String input) {
    if (input.trim().isEmpty) return null;
    try {
      final str = Uri.decodeComponent(input.trim());
      final candidates = [str, input.trim()];
      for (final t in candidates) {
        final m1 = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(t);
        if (m1 != null) return {'lat': double.parse(m1.group(1)!), 'lon': double.parse(m1.group(2)!)};

        final mEmbed = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)').firstMatch(t);
        if (mEmbed != null) return {'lat': double.parse(mEmbed.group(1)!), 'lon': double.parse(mEmbed.group(2)!)};

        final m2 = RegExp(r'[?&](?:q|ll|sll|query|center|daddr|destination|saddr)=(?:loc:)?(-?\d+\.\d+),(-?\d+\.\d+)', caseSensitive: false).firstMatch(t);
        if (m2 != null) return {'lat': double.parse(m2.group(1)!), 'lon': double.parse(m2.group(2)!)};

        final m3 = RegExp(r'(-?\d{1,2}\.\d{3,})\s*[,; ]\s*(-?\d{1,3}\.\d{3,})').firstMatch(t);
        if (m3 != null) {
          final lat = double.parse(m3.group(1)!);
          final lon = double.parse(m3.group(2)!);
          if (lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180) {
            return {'lat': lat, 'lon': lon};
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _showQrStoreModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FutureBuilder<http.Response>(
        future: Provider.of<ApiService>(context, listen: false).get(ApiConfig.qrConfigUrl, requireAuth: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 280,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          Map<String, dynamic>? data;
          if (snapshot.hasData && snapshot.data != null) {
            try {
              data = jsonDecode(snapshot.data!.body) as Map<String, dynamic>?;
            } catch (_) {}
          }

          final qrUrl = data?['qr_image_url'] as String?;
          final banco = (data?['banco_nombre'] ?? 'Banco BNB / BCP / Unión').toString();
          final cuenta = (data?['numero_cuenta'] ?? '10000034928123').toString();
          final titular = (data?['titular_cuenta'] ?? 'StyleStore S.R.L.').toString();
          final expira = (data?['fecha_expiracion'] ?? '').toString();

          return Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.qr_code_2, color: Color(0xFF0F766E), size: 26),
                        SizedBox(width: 8),
                        Text(
                          'QR Simple de Cobro',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (qrUrl != null && qrUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      qrUrl.startsWith('http') ? qrUrl : '${ApiConfig.baseUrl.replaceAll('/api/v1', '')}$qrUrl',
                      height: 260,
                      width: 260,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        height: 240,
                        width: 240,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.qr_code_2, size: 110, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 240,
                    width: 240,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.qr_code_2, size: 110, color: Color(0xFF0F766E)),
                  ),
                const SizedBox(height: 12),
                Text(
                  titular,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  '$banco • Cta: $cuenta',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                if (expira.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Válido hasta: $expira',
                    style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x0D0F766E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Escanea este código con cualquier aplicación bancaria boliviana (BNB, BCP, Banco Unión, etc.) para abonar a la tienda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF0F766E)),
                  ),
                ),
                Builder(
                  builder: (innerContext) {
                    final user = Provider.of<AuthService>(context, listen: false).currentUser;
                    final isStaff = user != null && (user.role == 'admin' || user.role == 'encargado');
                    if (!isStaff) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showUpdateQrDialog(context, data);
                        },
                        icon: const Icon(Icons.edit, size: 16, color: AppTheme.accentIndigo),
                        label: const Text('Actualizar QR (Admin/Encargado)', style: TextStyle(fontSize: 12, color: AppTheme.accentIndigo, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showUpdateQrDialog(BuildContext context, Map<String, dynamic>? currentData) {
    final bancoCtrl = TextEditingController(text: currentData?['banco_nombre'] ?? 'Banco BNB');
    final cuentaCtrl = TextEditingController(text: currentData?['numero_cuenta'] ?? '');
    final titularCtrl = TextEditingController(text: currentData?['titular_cuenta'] ?? 'StyleStore S.R.L.');
    final expiraCtrl = TextEditingController(text: currentData?['fecha_expiracion'] ?? '');
    final urlCtrl = TextEditingController(text: currentData?['qr_image_url'] ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: AppTheme.accentIndigo),
            SizedBox(width: 8),
            Text('Actualizar QR Mostrador', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'URL o Path de Imagen QR', hintText: '/uploads/qr/qr.png'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bancoCtrl,
                decoration: const InputDecoration(labelText: 'Banco', hintText: 'Banco BNB'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cuentaCtrl,
                decoration: const InputDecoration(labelText: 'Número de Cuenta'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titularCtrl,
                decoration: const InputDecoration(labelText: 'Titular de la Cuenta'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: expiraCtrl,
                decoration: const InputDecoration(labelText: 'Fecha de Expiración', hintText: 'YYYY-MM-DD o DD/MM/YYYY'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final apiService = Provider.of<ApiService>(context, listen: false);
                await apiService.post(
                  ApiConfig.qrConfigUrl,
                  body: {
                    'qr_image_url': urlCtrl.text.trim(),
                    'banco_nombre': bancoCtrl.text.trim(),
                    'numero_cuenta': cuentaCtrl.text.trim(),
                    'titular_cuenta': titularCtrl.text.trim(),
                    'fecha_expiracion': expiraCtrl.text.trim(),
                  },
                );
                if (context.mounted) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('QR actualizado exitosamente')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al actualizar QR: $e')),
                  );
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showCheckoutModal(CartService cartService) {
    final addressCtrl = TextEditingController(text: 'Av. América #450');
    final mapsCtrl = TextEditingController();
    double distanciaKm = 4.5;

    final catalogService = Provider.of<CatalogService>(context, listen: false);
    final sucursalId = cartService.items.isNotEmpty ? cartService.items.first.sucursalId : catalogService.selectedSucursalId;
    Map<String, dynamic>? branch;
    if (catalogService.sucursales.isNotEmpty) {
      try {
        branch = catalogService.sucursales.firstWhere(
          (s) => s['id'] == sucursalId,
          orElse: () => catalogService.sucursales.first,
        );
      } catch (_) {
        branch = catalogService.sucursales.first;
      }
    }
    final branchName = (cartService.items.isNotEmpty && cartService.items.first.sucursalNombre != null)
        ? cartService.items.first.sucursalNombre!
        : (branch != null ? (branch['nombre'] ?? branch['name'] ?? 'Sucursal Central') : 'Sucursal StyleStore');
    final branchMapsUrl = (cartService.items.isNotEmpty ? cartService.items.first.sucursalMapsUrl : null) ??
        (branch != null ? (branch['maps_url'] ?? branch['ubicacion_url']) : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final double costoEnvio = 5.0 + (distanciaKm * 0.60);
            final double totalPagar = cartService.total + costoEnvio;

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

                    // Alerta informativa Delivery StyleStore con Maps de Sucursal
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x1A14263D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x6614263D)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.local_shipping_outlined, color: Color(0xFF14263D), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Delivery StyleStore: Servicio privado de despacho. Tarifa fija de Bs. 5.00 + Bs. 0.60 por kilómetro desde la sucursal.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.3),
                                ),
                              ),
                            ],
                          ),
                          if (branchMapsUrl != null && branchMapsUrl.toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: branchMapsUrl.toString()));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('📍 Enlace de Maps de $branchName copiado'),
                                    backgroundColor: AppTheme.accentIndigo,
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0x806366F1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.location_on, size: 16, color: AppTheme.accentIndigo),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Ver ubicación de $branchName en Google Maps ↗',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentIndigo),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
                        labelText: 'Enlace de Google Maps (Ubicación exacta del cliente)',
                        hintText: 'https://maps.app.goo.gl/...',
                        prefixIcon: const Icon(Icons.location_on, color: AppTheme.accentIndigo),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Selector dinámico de distancia y desglose de tarifa
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderGlass),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Distancia de entrega estimada:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                              Text('${distanciaKm.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.accentIndigo)),
                            ],
                          ),
                          Slider(
                            value: distanciaKm,
                            min: 1.0,
                            max: 35.0,
                            divisions: 68,
                            activeColor: AppTheme.accentIndigo,
                            label: '${distanciaKm.toStringAsFixed(1)} km',
                            onChanged: (val) {
                              setModalState(() {
                                distanciaKm = double.parse(val.toStringAsFixed(1));
                              });
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Costo Delivery (5Bs + 0.6Bs/km):', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              Text('Bs. ${costoEnvio.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF14263D))),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total a Pagar (Prendas + Envío):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF14263D))),
                              Text('Bs. ${totalPagar.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF14263D))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

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
                                Text('Pago seguro internacional. Para compras presenciales en efectivo o QR Simple visita nuestras cajas POS en tienda física.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // QR Mostrador info
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showQrStoreModal(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0x0D0F766E),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x4414B8A6)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.qr_code_2, color: Color(0xFF0F766E), size: 24),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('📱 Pago por QR Simple en Mostrador', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                                    SizedBox(height: 2),
                                    Text('Toca aquí para ver el código QR de cobro oficial y pagar con tu banca móvil.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF0F766E)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    ElevatedButton(
                      onPressed: () async {
                        final address = addressCtrl.text.trim();
                        final mapsUrl = mapsCtrl.text.trim();
                        if (address.isEmpty && mapsUrl.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Por favor ingresa la dirección de entrega o enlace de Maps.')),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        final direccionCompleta = mapsUrl.isNotEmpty
                            ? (address.isNotEmpty ? '$address | Maps: $mapsUrl' : mapsUrl)
                            : address;

                        // Extraer coordenadas GPS del enlace si existen
                        double? latDestino;
                        double? lonDestino;
                        if (mapsUrl.isNotEmpty) {
                          final coords = _extraerCoordsMaps(mapsUrl);
                          if (coords != null) {
                            latDestino = coords['lat'];
                            lonDestino = coords['lon'];
                          }
                        }

                        final res = await cartService.checkout(
                          metodoPago: 'paypal',
                          distanciaKm: distanciaKm,
                          direccionEnvio: direccionCompleta,
                          latitudDestino: latDestino,
                          longitudDestino: lonDestino,
                          ubicacionUrl: mapsUrl.isNotEmpty ? mapsUrl : null,
                          ciudad: branch != null ? (branch['ciudad'] ?? 'Santa Cruz') : 'Santa Cruz',
                          sucursalId: sucursalId,
                        );
                        if (mounted) {
                          final token = res?['token_seguimiento'] as String?;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(res != null ? '¡Orden generada con éxito con PayPal!' : 'Pedido procesado.'),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                          Provider.of<OrderService>(context, listen: false).fetchOrders();
                          _tabController.animateTo(4); // Tab de Mis Pedidos

                          // Si tenemos token de rastreo, navegar directo a la pantalla de rastreo en vivo
                          if (token != null && token.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeliveryTrackingScreen(token: token),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14263D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Confirmar y Pagar Bs. ${totalPagar.toStringAsFixed(2)} con PayPal', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getEnvioStatusColor(order.envioEstado!),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('Envío: ${order.envioEstado}', style: const TextStyle(fontSize: 12, color: AppTheme.accentIndigo, fontWeight: FontWeight.w600)),
              ],
            ),
          ],

          // TARJETA DE RASTREO DELIVERY STYLESTORE
          if (order.trackingCode != null && order.trackingCode!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0x1A14263D), Color(0x0DC5A880)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x4414263D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accentIndigo,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_shipping, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Delivery StyleStore',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (order.minutosEstimados != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x2610B981),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '~${order.minutosEstimados} min',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.successGreen),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.qr_code, size: 16, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Código: ${order.trackingCode}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  if (order.deliveryConductor != null && order.deliveryConductor!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_pin, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Conductor: ${order.deliveryConductor}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                  if (order.repartidorNombre != null && order.repartidorNombre!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.badge, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Repartidor: ${order.repartidorNombre}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: order.trackingCode!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Código de rastreo copiado.'),
                                backgroundColor: AppTheme.accentIndigo,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 14),
                          label: const Text('Copiar Código'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentIndigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (order.tokenSeguimiento != null && order.tokenSeguimiento!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DeliveryTrackingScreen(
                                    token: order.tokenSeguimiento!,
                                    order: order,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.map_outlined, size: 14),
                            label: const Text('Rastrear Envío'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentIndigo,
                              side: const BorderSide(color: AppTheme.accentIndigo),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ] else if (order.trackingCode != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showTrackingDialog(order),
                            icon: const Icon(Icons.local_shipping_outlined, size: 14),
                            label: const Text('Info Envío'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentIndigo,
                              side: const BorderSide(color: AppTheme.accentIndigo),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
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

  Color _getEnvioStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'entregado':
        return AppTheme.successGreen;
      case 'en_camino':
      case 'en_ruta':
        return const Color(0xFFC5A880);
      case 'asignado':
      case 'preparando':
        return AppTheme.accentIndigo;
      case 'fallido':
      case 'cancelado':
        return AppTheme.dangerRed;
      default:
        return Colors.blueGrey;
    }
  }

  void _showTrackingDialog(OrderItem order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14263D).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.two_wheeler, color: Color(0xFF14263D), size: 24),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery StyleStore',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                          ),
                          Text(
                            'Rastreo de Entrega en Vivo',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgPrimary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderGlass),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Código de Rastreo:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        Text(
                          order.trackingCode ?? 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentIndigo),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estado del Envío:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        _buildTag(
                          (order.envioEstado ?? 'En Camino').toUpperCase(),
                          _getEnvioStatusColor(order.envioEstado ?? 'en_camino'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (order.repartidorNombre != null || order.deliveryConductor != null) ...[
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 16, color: Color(0xFFC5A880)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Repartidor: ${order.repartidorNombre ?? order.deliveryConductor}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (order.minutosEstimados != null) ...[
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFC5A880)),
                    const SizedBox(width: 8),
                    Text(
                      'Tiempo estimado: ~${order.minutosEstimados} minutos',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (order.repartidorLat != null && order.repartidorLon != null) ...[
                Row(
                  children: [
                    const Icon(Icons.gps_fixed, size: 16, color: AppTheme.successGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'GPS Repartidor: ${order.repartidorLat!.toStringAsFixed(4)}, ${order.repartidorLon!.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Provider.of<OrderService>(context, listen: false).fetchOrders();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Estado de pedidos actualizado.')),
                        );
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Actualizar Estado'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14263D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  if (order.trackingCode != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: order.trackingCode!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Código copiado al portapapeles.')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copiar Código'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentIndigo,
                        side: const BorderSide(color: AppTheme.accentIndigo),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
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
