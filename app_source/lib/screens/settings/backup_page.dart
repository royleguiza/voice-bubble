part of '../settings_screen.dart';

/// T1 · Ajustes › Copia de seguridad: exportar e importar un `.zip` con
/// notas (y sus audios), historial, snippets, portapapeles y ajustes. Las
/// claves de API y las credenciales nunca entran.
extension _BackupPage on _SettingsScreenState {
  Widget _buildCopiaPage(BuildContext context) {
    final l = context.l10n;
    return _subpage(
      context,
      title: l.settingsBackupTitle,
      sections: [
        SettingsSection(
          footer: l.settingsBackupFooter,
          children: [
            SettingsActionRow(
              key: const ValueKey('backup-export-row'),
              title: _backupBusy == BackupStatus.saved
                  ? l.settingsBackupExporting
                  : l.settingsBackupExport,
              onTap: _backupBusy == null ? _exportBackup : null,
            ),
            SettingsActionRow(
              key: const ValueKey('backup-import-row'),
              title: _backupBusy == BackupStatus.imported
                  ? l.settingsBackupImporting
                  : l.settingsBackupImport,
              onTap: _backupBusy == null ? _importBackup : null,
            ),
          ],
        ),
      ],
    );
  }
}
