import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/main.dart';

void main() {
  testWidgets('La app abre y alterna estado de grabación', (tester) async {
    await tester.pumpWidget(const VoiceBubbleApp());

    expect(find.text('Listo para transcribir'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(find.text('Grabando...'), findsOneWidget);
  });
}
