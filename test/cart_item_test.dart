import 'package:flutter_test/flutter_test.dart';
import 'package:stylestore_mobile/models/cart_item.dart';

void main() {
  test('preserva la sucursal requerida para cotizar delivery', () {
    final item = CartItem.fromJson({
      'id': 10,
      'producto_color_id': 20,
      'talla_id': 30,
      'sucursal_id': 40,
      'sucursal_nombre': 'Sucursal Equipetrol',
      'sucursal_ciudad': 'Santa Cruz',
      'sucursal_maps_url': 'https://www.google.com/maps?q=-17.78,-63.19',
      'producto_nombre': 'polo',
      'precio_unitario': '69.99',
      'cantidad': 1,
      'subtotal': '69.99',
    });

    expect(item.sucursalId, 40);
    expect(item.sucursalNombre, 'Sucursal Equipetrol');
    expect(item.sucursalCiudad, 'Santa Cruz');
    expect(item.sucursalMapsUrl, contains('google.com/maps'));
  });
}
