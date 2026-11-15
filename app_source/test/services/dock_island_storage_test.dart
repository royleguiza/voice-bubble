import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_bubble_stt/services/storage_service.dart';

/// Ajustes de la isla (fase 2B): las claves que lee DockLink (host) y manda
/// al complemento como DOCK_CONFIG. -1 = valor por defecto.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('StorageService - isla', () {
    test('por defecto: todo -1 y micrófono a la izquierda', () async {
      final s = StorageService();
      expect(await s.getDockIslandX(), -1);
      expect(await s.getDockIslandY(), -1);
      expect(await s.getDockIslandW(), -1);
      expect(await s.getDockIslandH(), -1);
      expect(await s.getDockIslandSide(), 'left');
    });

    test('guarda y relee medidas y lado', () async {
      final s = StorageService();
      await s.setDockIslandX(540);
      await s.setDockIslandY(24);
      await s.setDockIslandW(320);
      await s.setDockIslandH(84);
      await s.setDockIslandSide('right');
      expect(await s.getDockIslandX(), 540);
      expect(await s.getDockIslandY(), 24);
      expect(await s.getDockIslandW(), 320);
      expect(await s.getDockIslandH(), 84);
      expect(await s.getDockIslandSide(), 'right');
    });

    test('se guardan como Int con las claves del contrato', () async {
      final s = StorageService();
      await s.setDockIslandX(540);
      await s.setDockIslandSide('right');
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('dock_island_x'), 540);
      expect(p.getString('dock_island_side'), 'right');
    });

    test('0 es válido para x e y, pero ancho y alto 0 son "por defecto"',
        () async {
      final s = StorageService();
      await s.setDockIslandX(0);
      await s.setDockIslandY(0);
      await s.setDockIslandW(0);
      await s.setDockIslandH(0);
      expect(await s.getDockIslandX(), 0);
      expect(await s.getDockIslandY(), 0);
      expect(await s.getDockIslandW(), -1);
      expect(await s.getDockIslandH(), -1);
    });

    test('un valor negativo vuelve al valor por defecto', () async {
      final s = StorageService();
      await s.setDockIslandX(300);
      await s.setDockIslandX(-7);
      expect(await s.getDockIslandX(), -1);
    });

    test('se acota al tope del protocolo (20000 px)', () async {
      final s = StorageService();
      await s.setDockIslandX(999999);
      expect(await s.getDockIslandX(), StorageService.dockIslandMaxPx);
    });

    test('basura guardada cae al valor por defecto', () async {
      SharedPreferences.setMockInitialValues({
        'dock_island_x': 'cualquier cosa',
        'dock_island_y': -50,
        'dock_island_w': 99999999,
        'dock_island_h': '84',
        'dock_island_side': 'arriba',
      });
      final s = StorageService();
      expect(await s.getDockIslandX(), -1);
      expect(await s.getDockIslandY(), -1);
      expect(await s.getDockIslandW(), -1);
      expect(await s.getDockIslandH(), 84);
      expect(await s.getDockIslandSide(), 'left');
    });

    test('un lado inválido no se escribe', () async {
      final s = StorageService();
      await s.setDockIslandSide('centro');
      final p = await SharedPreferences.getInstance();
      expect(p.containsKey('dock_island_side'), isFalse);
    });

    test('la forma Isla es válida y entra al puente', () async {
      final s = StorageService();
      await s.setDockForm('island');
      expect(await s.getDockForm(), 'island');
      for (final k in [
        StorageService.dockIslandXKey,
        StorageService.dockIslandYKey,
        StorageService.dockIslandWKey,
        StorageService.dockIslandHKey,
        StorageService.dockIslandSideKey,
      ]) {
        expect(StorageService.bridgeKeys, contains(k));
      }
    });

    test('los dominios son los que entiende PointerProtocol', () {
      expect(StorageService.dockIslandSides, ['left', 'right']);
      expect(StorageService.dockIslandDefault, -1);
    });
  });
}
