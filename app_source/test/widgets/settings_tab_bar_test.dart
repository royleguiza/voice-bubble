import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/widgets/settings_tab_bar.dart';

void main() {
  testWidgets('SettingsTabBar renderiza 6 pestañas v1 con sus keys correspondientes',
      (tester) async {
    int selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: SettingsTabBar(
            selectedIndex: selected,
            onTabSelected: (i) => selected = i,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tab-inicio')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-burbuja')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-teclado')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-trackpad')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-snippets')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-credenciales')), findsOneWidget);

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Burbuja'), findsOneWidget);
    expect(find.text('Teclado'), findsOneWidget);
    expect(find.text('Trackpad'), findsOneWidget);
    expect(find.text('Snippets'), findsOneWidget);
    expect(find.text('Claves'), findsOneWidget);

    // Conteo exacto: agregar/quitar un tab debe romper aquí a propósito.
    final tabKeys = find.byWidgetPredicate((w) =>
        w.key is ValueKey &&
        (w.key as ValueKey).value is String &&
        ((w.key as ValueKey).value as String).startsWith('tab-'));
    expect(tabKeys, findsNWidgets(6));
  });

  testWidgets('SettingsTabBar dispara onTabSelected al tocar cada pestaña',
      (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: SettingsTabBar(
            selectedIndex: 0,
            onTabSelected: (i) => tapped.add(i),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tab-burbuja')));
    await tester.pumpAndSettle();
    expect(tapped, [1]);

    await tester.tap(find.byKey(const ValueKey('tab-teclado')));
    await tester.pumpAndSettle();
    expect(tapped, [1, 2]);

    await tester.tap(find.byKey(const ValueKey('tab-trackpad')));
    await tester.pumpAndSettle();
    expect(tapped, [1, 2, 3]);

    await tester.tap(find.byKey(const ValueKey('tab-snippets')));
    await tester.pumpAndSettle();
    expect(tapped, [1, 2, 3, 4]);

    await tester.tap(find.byKey(const ValueKey('tab-credenciales')));
    await tester.pumpAndSettle();
    expect(tapped, [1, 2, 3, 4, 5]);

    await tester.tap(find.byKey(const ValueKey('tab-inicio')));
    await tester.pumpAndSettle();
    expect(tapped, [1, 2, 3, 4, 5, 0]);
  });

  testWidgets('SettingsTabBar respeta Reduced Motion', (tester) async {
    int selected = 2;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: SettingsTabBar(
              selectedIndex: selected,
              onTabSelected: (i) => selected = i,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tab-teclado')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tab-snippets')));
    await tester.pump();
    expect(selected, 4);
  });

  testWidgets('SettingsTabBar funciona en tema oscuro', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          bottomNavigationBar: SettingsTabBar(
            selectedIndex: 4,
            onTabSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tab-snippets')), findsOneWidget);
  });
}
