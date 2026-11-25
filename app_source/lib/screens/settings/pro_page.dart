part of '../settings_screen.dart';

/// T15 · Ajustes › Orison Pro: estado (prueba, gratis o Pro), qué incluye,
/// precio (el que informa Play), Comprar y Restaurar compra.
extension _ProPage on _SettingsScreenState {
  Widget _buildProPage(BuildContext context) {
    final l = context.l10n;
    final p = SettingsPalette.of(context);
    final st = _proStatus;
    final until = ProService.launchPriceUntil;
    return ValueListenableBuilder<ProductDetails?>(
      valueListenable: ProService.instance.product,
      builder: (context, product, _) => ValueListenableBuilder<bool>(
        valueListenable: ProService.instance.unlocked,
        builder: (context, unlockedNow, _) {
          final unlocked = unlockedNow || (st?.unlocked ?? false);
          final String state;
          if (unlocked) {
            state = l.proStateUnlockedLong;
          } else if (st != null && st.inTrial) {
            state = l.proStateTrialLong(st.trialDaysLeft, ProGate.freeDailyDictations);
          } else {
            state = l.proStateFreeLong(st?.freeLeftToday ?? ProGate.freeDailyDictations, ProGate.freeDailyDictations);
          }
          return _subpage(
            context,
            title: l.proTitle,
            sections: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  state,
                  key: const ValueKey('pro-state'),
                  style: kTextCallout.copyWith(color: p.label, height: 1.45),
                ),
              ),
              SettingsSection(
                header: l.proIncludesHeader,
                footer: l.proIncludesFooter,
                children: [
                  SettingsValueRow(title: l.proIncludesDictation, value: '∞'),
                  SettingsValueRow(title: l.proIncludesAi, value: '∞'),
                  SettingsValueRow(title: l.proIncludesKeyboard, value: l.proAlwaysFree),
                ],
              ),
              if (!unlocked)
                SettingsSection(
                  footer: until != null && DateTime.now().isBefore(until)
                      ? l.proLaunchUntil(MaterialLocalizations.of(context).formatMediumDate(until))
                      : null,
                  children: [
                    SettingsActionRow(
                      key: const ValueKey('pro-buy'),
                      title: product == null ? l.proBuy : l.proBuyPrice(product.price),
                      onTap: _buyPro,
                    ),
                    SettingsActionRow(
                      key: const ValueKey('pro-restore'),
                      title: l.proRestore,
                      onTap: _restorePro,
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
