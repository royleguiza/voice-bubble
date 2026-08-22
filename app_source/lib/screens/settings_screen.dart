import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();
  bool _hasApiKey = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final key = await _secureStorage.read(key: 'groq_api_key') ?? '';
    if (mounted) {
      setState(() {
        _apiKeyController.text = key;
        _hasApiKey = key.isNotEmpty;
      });
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    await _secureStorage.write(key: 'groq_api_key', value: key);
    if (mounted) {
      setState(() => _hasApiKey = key.isNotEmpty);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key guardada')),
      );
    }
  }

  Future<void> _clearApiKey() async {
    await _secureStorage.delete(key: 'groq_api_key');
    if (mounted) {
      _apiKeyController.clear();
      setState(() => _hasApiKey = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key eliminada')),
      );
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // API Key section
          Text(
            'API Key de Groq',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Necesaria para el modo Cloud. Obtén tu clave en console.groq.com',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'gsk_...',
                    border: const OutlineInputBorder(),
                    suffixIcon: _hasApiKey
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveApiKey,
                tooltip: 'Guardar',
              ),
              if (_hasApiKey)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _clearApiKey,
                  tooltip: 'Borrar',
                ),
            ],
          ),

          const SizedBox(height: 32),

          // Transcription model section
          Text(
            'Modelo de transcripcion',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Modo Cloud',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              'Groq Whisper Large V3 (whisper-large-v3)',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.phone_android,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Modo Local',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              'Speech-to-Text del sistema Android',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'El modo local depende del motor de reconocimiento de voz del dispositivo.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // About section
          const Divider(),
          const SizedBox(height: 16),
          Text(
            'Acerca de',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'VoiceBubble STT v0.1.0',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Transcripción de voz a texto con modo Cloud (Groq) y Local (dispositivo).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
