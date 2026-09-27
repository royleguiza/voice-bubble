/// Fixture binario WAV PCM 16-bit mono 16kHz (C-42).
///
/// Los tests que suben audio mockeado deben partir de un contenedor válido:
/// desde C-42 `CloudSttService.transcribe` valida la cabecera antes de
/// enviar (un archivo de ceros ya no llega al mock HTTP).
List<int> validWavBytes([int dataSize = 8192]) {
  void u16(List<int> out, int v) {
    out.add(v & 0xFF);
    out.add((v >> 8) & 0xFF);
  }

  void u32(List<int> out, int v) {
    u16(out, v & 0xFFFF);
    u16(out, (v >> 16) & 0xFFFF);
  }

  void tag(List<int> out, String s) {
    for (var i = 0; i < 4; i++) {
      out.add(s.codeUnitAt(i));
    }
  }

  final List<int> head = <int>[];
  tag(head, 'RIFF');
  u32(head, dataSize + 36);
  tag(head, 'WAVE');
  tag(head, 'fmt ');
  u32(head, 16);
  u16(head, 1);
  u16(head, 1);
  u32(head, 16000);
  u32(head, 32000);
  u16(head, 2);
  u16(head, 16);
  tag(head, 'data');
  u32(head, dataSize);
  assert(head.length == 44);
  return head + List<int>.filled(dataSize, 0);
}
