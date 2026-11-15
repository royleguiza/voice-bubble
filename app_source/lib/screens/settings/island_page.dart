part of '../settings_screen.dart';

/// Subpágina «Ajustar isla» (Ajustes › Barra flotante, solo con la forma
/// Isla): una maqueta a escala real arriba, fija, y debajo los controles al
/// píxel. Cada cambio se guarda y el complemento mueve la isla de verdad EN
/// VIVO. Estado y guardado viven en [IslandAdjustBody] (como la velocidad
/// del puntero en Trackpad): arrastrar un deslizador no reconstruye Ajustes.
extension _IslandPage on _SettingsScreenState {
  Widget _buildIslaPage(BuildContext context) {
    return _subpage(
      context,
      title: 'Ajustar isla',
      body: IslandAdjustBody(
        storageService: _storageService,
        floatingBubbleService: _floatingBubbleService,
        pointerReady: _pointerStatus == FloatingTrackpadService.pointerReady,
        barOn: _isBubbleEnabled,
      ),
    );
  }
}

/// Qué campo de la isla cambió y falta guardar.
enum _IslandField { x, y, w, h, side }

class IslandAdjustBody extends StatefulWidget {
  final StorageService storageService;
  final FloatingBubbleService floatingBubbleService;

  /// El complemento VoiceBubble Puntero está activo (si no, la isla se ve
  /// como burbuja y los ajustes no se notan).
  final bool pointerReady;

  /// La barra flotante está encendida en Ajustes.
  final bool barOn;

  const IslandAdjustBody({
    super.key,
    required this.storageService,
    required this.floatingBubbleService,
    required this.pointerReady,
    required this.barOn,
  });

  @override
  State<IslandAdjustBody> createState() => _IslandAdjustBodyState();
}

class _IslandAdjustBodyState extends State<IslandAdjustBody> {
  /// Valores pedidos tal como se guardan (−1 = por defecto).
  int _x = IslandGeometry.auto;
  int _y = IslandGeometry.auto;
  int _w = IslandGeometry.auto;
  int _h = IslandGeometry.auto;
  String _side = StorageService.defaultDockIslandSide;

  /// Campos tocados que todavía no se guardaron: cada envío guarda TODOS los
  /// pendientes (el limitador se queda con la última acción, no con la última
  /// tecla) y recién después pide al nativo que reenvíe la configuración.
  final Set<_IslandField> _dirty = {};

  /// Mientras se arrastra: como mucho un envío cada 60 ms y siempre el valor
  /// final al soltar.
  final Throttler _throttler =
      Throttler(interval: const Duration(milliseconds: 60));

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final s = widget.storageService;
    final x = await s.getDockIslandX();
    final y = await s.getDockIslandY();
    final w = await s.getDockIslandW();
    final h = await s.getDockIslandH();
    final side = await s.getDockIslandSide();
    if (!mounted) return;
    setState(() {
      _x = x;
      _y = y;
      _w = w;
      _h = h;
      _side = side;
    });
  }

  @override
  void dispose() {
    _throttler.dispose();
    // Si se sale de la página a mitad de un gesto, el último valor igual se
    // guarda y llega a la isla.
    if (_dirty.isNotEmpty) {
      unawaited(_commit().catchError((Object _) {}));
    }
    super.dispose();
  }

  // --- guardado ---------------------------------------------------------

  Future<void> _save(_IslandField f) {
    final s = widget.storageService;
    return switch (f) {
      _IslandField.x => s.setDockIslandX(_x),
      _IslandField.y => s.setDockIslandY(_y),
      _IslandField.w => s.setDockIslandW(_w),
      _IslandField.h => s.setDockIslandH(_h),
      _IslandField.side => s.setDockIslandSide(_side),
    };
  }

  Future<void> _commit() async {
    final fields = _dirty.toList();
    if (fields.isEmpty) return;
    _dirty.clear();
    for (final f in fields) {
      await _save(f);
    }
    await widget.floatingBubbleService.reloadDock();
  }

  /// Marca el campo y lo guarda a más tardar en 60 ms (arrastre, repetición).
  void _queue(_IslandField f) {
    _dirty.add(f);
    _throttler.run(_commit);
  }

  /// Guarda ya lo pendiente (dedo suelto, toque suelto, botones).
  Future<void> _commitNow() {
    _throttler.run(_commit);
    return _throttler.flush();
  }

  void _setPx(_IslandField f, int px) {
    setState(() {
      switch (f) {
        case _IslandField.x:
          _x = px;
        case _IslandField.y:
          _y = px;
        case _IslandField.w:
          _w = px;
        case _IslandField.h:
          _h = px;
        case _IslandField.side:
          break;
      }
    });
    _queue(f);
  }

  void _setSide(String side) {
    setState(() => _side = side);
    _queue(_IslandField.side);
    unawaited(_commitNow());
  }

  /// X al centro de la pantalla, Y por defecto (el ancho y el alto quedan).
  void _centerOnTop() {
    setState(() {
      _x = IslandGeometry.auto;
      _y = IslandGeometry.auto;
    });
    _dirty
      ..add(_IslandField.x)
      ..add(_IslandField.y);
    unawaited(_commitNow());
  }

  /// Todo vuelve a su valor por defecto (medidas −1, micrófono a la izquierda).
  void _reset() {
    setState(() {
      _x = _y = _w = _h = IslandGeometry.auto;
      _side = StorageService.defaultDockIslandSide;
    });
    _dirty.addAll(_IslandField.values);
    unawaited(_commitNow());
  }

  // --- pantalla ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Pantalla completa real: tamaño físico y densidad de la vista.
    final view = View.of(context);
    final geo = IslandGeometry(
      screen: view.physicalSize,
      density: view.devicePixelRatio,
    );
    final width = geo.resolveWidth(_w);
    final height = geo.resolveHeight(_h);
    final centerX = geo.resolveCenterX(_x, width);
    final top = geo.resolveTop(_y, height);
    final micOnLeft = _side != 'right';

    SettingsStepperRow stepper({
      required String id,
      required String title,
      required int value,
      required int min,
      required int max,
      required _IslandField field,
      required String minusLabel,
      required String plusLabel,
    }) =>
        SettingsStepperRow(
          id: id,
          title: title,
          value: value,
          min: min,
          max: max,
          minusLabel: minusLabel,
          plusLabel: plusLabel,
          onChanged: (v) => _setPx(field, v),
          onChangeEnd: () => unawaited(_commitNow()),
        );

    final notes = <String>[
      if (!widget.pointerReady)
        'La isla necesita VoiceBubble Puntero activo: sin él se ve como '
            'burbuja y estos ajustes no se notan.',
      if (!widget.barOn)
        'Encendé la barra flotante para ver la isla en tu pantalla.',
    ];

    final sections = <Widget>[
      SettingsSection(
        header: 'Posición',
        footer: 'Horizontal: el centro de la isla. Vertical: su borde '
            'superior. En píxeles de la pantalla completa.',
        children: [
          stepper(
            id: 'island-x',
            title: 'Posición horizontal',
            value: centerX,
            min: geo.minCenterX(width),
            max: geo.maxCenterX(width),
            field: _IslandField.x,
            minusLabel: 'Un píxel a la izquierda',
            plusLabel: 'Un píxel a la derecha',
          ),
          stepper(
            id: 'island-y',
            title: 'Posición vertical',
            value: top,
            min: 0,
            max: geo.maxTop,
            field: _IslandField.y,
            minusLabel: 'Un píxel hacia arriba',
            plusLabel: 'Un píxel hacia abajo',
          ),
        ],
      ),
      SettingsSection(
        header: 'Tamaño en reposo',
        footer: 'Al grabar, la isla se agranda sola.',
        children: [
          stepper(
            id: 'island-w',
            title: 'Ancho',
            value: width,
            min: geo.minWidth,
            max: geo.maxWidth,
            field: _IslandField.w,
            minusLabel: 'Un píxel más angosta',
            plusLabel: 'Un píxel más ancha',
          ),
          stepper(
            id: 'island-h',
            title: 'Alto',
            value: height,
            min: geo.minHeight,
            max: geo.maxHeight,
            field: _IslandField.h,
            minusLabel: 'Un píxel más baja',
            plusLabel: 'Un píxel más alta',
          ),
        ],
      ),
      SettingsSection(
        footer: 'El puntero va del otro lado.',
        children: [
          SettingsMenuRow<String>(
            id: 'island-side-selector',
            title: 'Lado del micrófono',
            value: _side,
            options: const [
              SettingsOption('left', 'Izquierda'),
              SettingsOption('right', 'Derecha'),
            ],
            onSelected: _setSide,
          ),
        ],
      ),
      SettingsSection(
        footer: notes.isEmpty ? null : notes.join('\n'),
        children: [
          SettingsActionRow(
            key: const ValueKey('island-center-button'),
            title: 'Centrar arriba',
            onTap: _centerOnTop,
          ),
          SettingsActionRow(
            key: const ValueKey('island-reset-button'),
            title: 'Restablecer',
            onTap: _reset,
          ),
        ],
      ),
    ];

    final children = <Widget>[];
    for (var i = 0; i < sections.length; i++) {
      if (i > 0) children.add(const SizedBox(height: kSettingsGroupGap));
      children.add(sections[i]);
    }

    return Column(
      children: [
        // La maqueta queda fija arriba: se ve mientras se ajusta, sin
        // tener que volver a subir la página.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: IslandMockup(
            screenPx: view.physicalSize,
            density: view.devicePixelRatio,
            x: _x,
            y: _y,
            w: _w,
            h: _h,
            micOnLeft: micOnLeft,
          ),
        ),
        Expanded(
          child: ListView(
            key: const PageStorageKey<String>('settings_ajustar_isla'),
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              kSettingsGroupGap + MediaQuery.paddingOf(context).bottom,
            ),
            children: children,
          ),
        ),
      ],
    );
  }
}
