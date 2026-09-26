import 'dart:math';

/// Genera un identificador único universal RFC 4122 versión 4.
/// Formato canónico: `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx` en minúsculas.
/// Totalmente determinista ante un generador [random] inyectado y criptográficamente
/// seguro por defecto mediante [Random.secure].
String generateUuidV4([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

  // Versión 4: bits 4-7 del byte 6 fijados en 0100 (0x40)
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  // Variante RFC 4122: bits 6-7 del byte 8 fijados en 10xx (0x80)
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String byteToHex(int b) => b.toRadixString(16).padLeft(2, '0');

  final p1 = bytes.sublist(0, 4).map(byteToHex).join();
  final p2 = bytes.sublist(4, 6).map(byteToHex).join();
  final p3 = bytes.sublist(6, 8).map(byteToHex).join();
  final p4 = bytes.sublist(8, 10).map(byteToHex).join();
  final p5 = bytes.sublist(10, 16).map(byteToHex).join();

  return '$p1-$p2-$p3-$p4-$p5';
}
