import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Guardia compartida para los MethodChannel nativos (burbuja, trackpad,
/// teclado): un solo helper en vez de tres copias de `_invokeBool`.
///
/// Distingue permiso-denegado (esperable sin overlay) de errores reales y
/// siempre devuelve un valor seguro en vez de lanzar.
const List<String> _permissionDeniedMarkers = ['PERMISSION_DENIED', 'DENIED'];

/// true si [code] (de `PlatformException.code`) indica permiso denegado.
/// Comparación en mayúsculas para tolerar variantes del lado nativo.
bool isPermissionDeniedCode(String code) {
  final upper = code.toUpperCase();
  return _permissionDeniedMarkers.any(upper.contains);
}

/// Invoca [method] esperando un bool, sin lanzar nunca: cualquier fallo de
/// canal/plataforma se registra con [tag] y devuelve false.
Future<bool> invokeChannelBool(
  MethodChannel channel,
  String tag,
  String method, [
  Map<String, Object?>? args,
]) async {
  try {
    final res = await channel.invokeMethod<bool>(method, args);
    return res ?? false;
  } on PlatformException catch (e) {
    if (isPermissionDeniedCode(e.code)) {
      debugPrint('$tag.$method: permiso denegado (${e.code})');
    } else {
      debugPrint('$tag.$method: PlatformException (${e.code}): ${e.message}');
    }
    return false;
  } on MissingPluginException catch (e) {
    debugPrint('$tag.$method: canal no disponible: $e');
    return false;
  } catch (e) {
    debugPrint('$tag.$method: error inesperado: $e');
    return false;
  }
}
