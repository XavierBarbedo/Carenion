import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/settings_service.dart';
import 'auth_pages.dart';

class SettingsPage extends StatefulWidget {
  final SettingsService settingsService;

  const SettingsPage({super.key, required this.settingsService});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _thresholdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _thresholdController.text =
        widget.settingsService.lowStockThreshold.toString();
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'images/carenion_Icon-removebg-preview.png',
              height: 35,
            ),
            const SizedBox(width: 10),
            const Text(
              'Definições',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2600)
            : const Color(0xFFFFFBE6),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.amber),
      ),
      body: ListenableBuilder(
        listenable: widget.settingsService,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSectionHeader('Geral', Icons.tune),
              _buildThemeDropdown(),
              _buildLanguageDropdown(),
              const Divider(height: 32),
              _buildSectionHeader('Agenda & Eventos', Icons.event_note),
              _buildNotificationDropdown(),
              const Divider(height: 32),
              _buildSectionHeader('Medicação & Stock', Icons.medication),
              _buildLowStockField(),
              const Divider(height: 32),
              _buildSectionHeader('Conta', Icons.person),
              _buildSignOutTile(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _signOut() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminar Sessão'),
        content: const Text('Deseja terminar sessão?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildSignOutTile() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.logout, color: Colors.red),
      title: const Text(
        'Terminar Sessão',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ),
      onTap: _signOut,
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 28),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeDropdown() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Tema da Aplicação',
          style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: const Text('Escolha entre Claro, Escuro ou o Padrão do Sistema'),
      trailing: DropdownButton<ThemeMode>(
        value: widget.settingsService.themeMode,
        onChanged: (ThemeMode? newMode) {
          if (newMode != null) {
            widget.settingsService.updateThemeMode(newMode);
          }
        },
        items: const [
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text('Sistema'),
          ),
          DropdownMenuItem(
            value: ThemeMode.light,
            child: Text('Claro'),
          ),
          DropdownMenuItem(
            value: ThemeMode.dark,
            child: Text('Escuro'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationDropdown() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Aviso de Eventos Próximos',
          style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: const Text(
          'Destaque no botão e aviso visual de eventos muito próximos'),
      trailing: DropdownButton<int>(
        value: widget.settingsService.eventNotificationTime,
        onChanged: (int? newMinutes) {
          if (newMinutes != null) {
            widget.settingsService.updateEventNotificationTime(newMinutes);
          }
        },
        items: const [
          DropdownMenuItem(
            value: 15,
            child: Text('15 Minutos'),
          ),
          DropdownMenuItem(
            value: 30,
            child: Text('30 Minutos'),
          ),
          DropdownMenuItem(
            value: 60,
            child: Text('1 Hora'),
          ),
          DropdownMenuItem(
            value: 120,
            child: Text('2 Horas'),
          ),
          DropdownMenuItem(
            value: 1440,
            child: Text('1 Dia'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Idioma do Calendário',
          style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: const Text('Selecione o idioma da agenda de cuidados'),
      trailing: DropdownButton<String>(
        value: widget.settingsService.calendarLanguage,
        onChanged: (String? newLang) {
          if (newLang != null) {
            widget.settingsService.updateCalendarLanguage(newLang);
          }
        },
        items: const [
          DropdownMenuItem(
            value: 'pt',
            child: Text('Português'),
          ),
          DropdownMenuItem(
            value: 'en',
            child: Text('English'),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockField() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Alerta de Stock Baixo',
          style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle:
          const Text('Limite de unidades a partir do qual será avisado'),
      trailing: SizedBox(
        width: 100,
        child: TextField(
          controller: _thresholdController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            suffixText: 'unid.',
            isDense: true,
          ),
          onChanged: (value) {
            final int? val = int.tryParse(value);
            if (val != null && val >= 0) {
              widget.settingsService.updateLowStockThreshold(val);
            }
          },
        ),
      ),
    );
  }
}
