/// Identidad de la app (T2): un solo lugar para el nombre y la versión que
/// se muestran en Acerca de y viajan en la copia de seguridad.
/// La versión debe coincidir con `version:` de pubspec.yaml.
abstract final class AppInfo {
  static const String name = 'Orison';
  static const String version = '1.0.0';
  static const String packageId = 'com.royleguiza.orison';

  /// Dirección pública de la política (T4). Vacía hasta que el dueño la
  /// publique: Acerca de muestra entonces solo el resumen.
  static const String privacyPolicyUrl = '';
}
