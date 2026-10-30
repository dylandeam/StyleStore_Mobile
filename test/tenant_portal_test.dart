import 'package:flutter_test/flutter_test.dart';
import 'package:stylestore_mobile/models/tenant_portal.dart';

void main() {
  test('interpreta la identidad visual del tenant y sus colores', () {
    final portal = TenantPortal.fromJson({
      'id': 7,
      'codigo': 'varones',
      'nombre': 'Ropa Varones SRL',
      'nombre_marca': 'Varones',
      'eslogan': 'Viste mejor',
      'color_primario': '#102030',
      'color_secundario': '#F8F7F2',
      'color_acento': '#A06020',
      'color_fondo': '#EEE8DB',
      'color_texto': '#172536',
      'color_texto_contraste': '#FFFDF8',
    });

    expect(portal.codigo, 'varones');
    expect(portal.nombreMarca, 'Varones');
    expect(portal.primaryColor.toARGB32(), 0xFF102030);
    expect(portal.contrastTextColor.toARGB32(), 0xFFFFFDF8);
    expect(TenantPortal.fromJson(portal.toJson()).eslogan, 'Viste mejor');
    expect(
      TenantPortal.fromJson(portal.toJson()).colorTextoContraste,
      '#FFFDF8',
    );
  });
}
