import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_bubble_stt/widgets/settings_tab_bar.dart';

void main() {
  testWidgets('SettingsTabBar renderiza 4 pestañas con sus keys correspondientes',
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

    expect(find.byKey(const ValueKey('tab-general')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-teclado')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-snippets')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-acerca')), findsOneWidget);

    expect(find.text('General'), findsOneWidget);
    expect(find.text('Teclado'), findsOneWidget);
    expect(find.text('Snippets'), findsOneWidget);
    expect(find.text('Acerca'), findsOneWidget);
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

    await tester.tap(find.byKey(const ValueKey('tab-teclado')));
    await tester.pumpAndSettle();
    expect(tapped, [1]);

    await tester.tap(find.byKey(const ValueKey('tab-snippets')));
    await tester.pumpAndSettle();
    expect(tapped, [1, 2]);

    await tester.tap(find.byKey(const ValueKey('tab-acerca')));
    await tester.pumpAndSettle();
    expect(tapped, [1, 2, 3]);

    await tester.tap(find.byKey(const ValueKey('tab-general')));
    await tester.pumpAndSettle();
    expect(tapped, [1, 2, 3, 0]);
  });

  testWidgets('SettingsTabBar respeta Reduced Motion', (tester) async {
    int selected = 1;
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
    expect(selected, 2);
  });

  testWidgets('SettingsTabBar funciona en tema oscuro', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          bottomNavigationBar: SettingsTabBar(
            selectedIndex: 2,
            onTabSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tab-snippets')), findsOneWidget);
  });
}
