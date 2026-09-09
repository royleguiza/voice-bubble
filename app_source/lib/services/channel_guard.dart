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
  return (await invokeChannelResult(channel, tag, method, args)).ok;
}

/// SPK-20: resultado clasificado para no tragar errores en release.
/// `debugPrint` no sale en release; el llamador distingue permiso-denegado
/// (esperable) de binder-roto (bug) sin contenido sensible.
enum ChannelFailKind { ok, permissionDenied, missingPlugin, platformError, unexpected }

class ChannelResult {
  final bool ok;
  final ChannelFailKind kind;
  final String? code;
  const ChannelResult(this.ok, this.kind, [this.code]);
}

int _channelErrorCount = 0;

/// Contador release-safe de fallos no-permiso (sin contenido).
int get channelErrorCount => _channelErrorCount;

Future<ChannelResult> invokeChannelResult(
  MethodChannel channel,
  String tag,
  String method, [
  Map<String, Object?>? args,
]) async {
  try {
    final res = await channel.invokeMethod<bool>(method, args);
    return ChannelResult(res ?? false, ChannelFailKind.ok);
  } on PlatformException catch (e) {
    if (isPermissionDeniedCode(e.code)) {
      debugPrint('$tag.$method: permiso denegado (${e.code})');
      return ChannelResult(false, ChannelFailKind.permissionDenied, e.code);
    } else {
      // Sin assert: los tests de servicios simulan PlatformException y
      // exigen `false` elegante (nunca lanzar, ver doc superior); la
      // visibilidad en debug la dan debugPrint + kind/code + contador.
      debugPrint('$tag.$method: PlatformException (${e.code}): ${e.message}');
      _channelErrorCount++;
      return ChannelResult(false, ChannelFailKind.platformError, e.code);
    }
  } on MissingPluginException catch (e) {
    debugPrint('$tag.$method: canal no disponible: $e');
    _channelErrorCount++;
    return const ChannelResult(false, ChannelFailKind.missingPlugin);
  } catch (e) {
    debugPrint('$tag.$method: error inesperado: $e');
    _channelErrorCount++;
    return const ChannelResult(false, ChannelFailKind.unexpected);
  }
}
