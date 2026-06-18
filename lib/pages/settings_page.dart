import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../services/settings_service.dart';
import '../utils.dart';
import 'auth_pages.dart';

class SettingsPage extends StatefulWidget {
  final SettingsService settingsService;
  final Map<String, dynamic> userData;

  const SettingsPage({
    super.key,
    required this.settingsService,
    required this.userData,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _thresholdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _thresholdController.text = widget.settingsService.lowStockThreshold
        .toString();
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
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
              _buildProfileCard(),
              const SizedBox(height: 12),
              _buildChangeNameTile(),
              _buildChangeEmailTile(),
              _buildChangePasswordTile(),
              _buildSignOutTile(),
              _buildDeleteAccountTile(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Apagar Conta',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Atenção: Esta ação é irreversível.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'Todos os seus dados, incluindo famílias, idosos e medicação associada, serão permanentemente eliminados.',
              ),
              SizedBox(height: 12),
              Text('Deseja mesmo apagar a sua conta?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Apagar Definitivamente'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final supabase = Supabase.instance.client;
        final userId = widget.userData['id'];

        // 1. Eliminar o registo do utilizador na tabela 'users'
        // Se houver ON DELETE CASCADE na BD (que é o padrão para manter integridade),
        // isto deve limpar os dados relacionados.
        await supabase.from('users').delete().eq('id', userId);

        // 2. Terminar sessão (isto limpa o token local)
        await supabase.auth.signOut();

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Conta apagada com sucesso. Lamentamos vê-lo partir.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erro ao apagar conta: ${translateSupabaseError(e)}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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

  Widget _buildDeleteAccountTile() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.delete_forever, color: Colors.red),
      title: const Text(
        'Apagar Conta',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      ),
      onTap: _deleteAccount,
    );
  }

  Widget _buildChangeNameTile() {
    final currentName = widget.userData['nome'] ?? '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.badge_outlined, color: Colors.amber),
      title: const Text(
        'Mudar Nome',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: currentName.isNotEmpty ? Text(currentName, style: const TextStyle(fontSize: 13)) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: _showChangeNameDialog,
    );
  }

  Future<void> _showChangeNameDialog() async {
    final nomeController = TextEditingController(
      text: widget.userData['nome'] ?? '',
    );
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Mudar Nome',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: TextField(
              controller: nomeController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                label: buildRequiredLabel('Nome Completo'),
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final novoNome = nomeController.text.trim();
                      if (novoNome.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('O nome não pode estar vazio.')),
                        );
                        return;
                      }
                      setDialogState(() => isLoading = true);
                      try {
                        final supabase = Supabase.instance.client;
                        final userId = widget.userData['id'];
                        await supabase
                            .from('users')
                            .update({'nome': novoNome})
                            .eq('id', userId);
                        if (mounted) {
                          setState(() {
                            widget.userData['nome'] = novoNome;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nome atualizado com sucesso!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro ao atualizar: ${translateSupabaseError(e)}'),
                            ),
                          );
                        }
                      } finally {
                        setDialogState(() => isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Confirmar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangePasswordTile() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.lock_outline, color: Colors.amber),
      title: const Text(
        'Mudar Palavra-passe',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showChangePasswordDialog,
    );
  }

  Widget _buildChangeEmailTile() {
    final userEmail = widget.userData['email'] ?? '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.email_outlined, color: Colors.amber),
      title: const Text(
        'Mudar Email',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(userEmail),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showChangeEmailDialog,
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool currentObscure = true;
    bool newObscure = true;
    bool confirmObscure = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Mudar Palavra-passe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: currentObscure,
                  decoration: InputDecoration(
                    label: buildRequiredLabel('Palavra-passe Atual'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        currentObscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(
                        () => currentObscure = !currentObscure,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: newObscure,
                  decoration: InputDecoration(
                    label: buildRequiredLabel('Nova Palavra-passe'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        newObscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setDialogState(() => newObscure = !newObscure),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: confirmObscure,
                  decoration: InputDecoration(
                    label: buildRequiredLabel('Confirmar Nova Palavra-passe'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        confirmObscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(
                        () => confirmObscure = !confirmObscure,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (newPasswordController.text !=
                          confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('As passwords não coincidem'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      try {
                        final supabase = Supabase.instance.client;
                        final user = supabase.auth.currentUser;

                        // Verificar password atual re-autenticando
                        await supabase.auth.signInWithPassword(
                          email: user!.email!,
                          password: currentPasswordController.text,
                        );

                        // Atualizar password
                        await supabase.auth.updateUser(
                          UserAttributes(password: newPasswordController.text),
                        );

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Palavra-passe atualizada com sucesso!',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Erro ao atualizar: ${translateSupabaseError(e)}',
                              ),
                            ),
                          );
                        }
                      } finally {
                        setDialogState(() => isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirmar',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangeEmailDialog() async {
    final currentPasswordController = TextEditingController();
    final newEmailController = TextEditingController();
    bool isLoading = false;
    bool obscureCurrent = true;
    final currentEmail = Supabase.instance.client.auth.currentUser?.email ?? '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Mudar Email'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email atual: ${widget.userData['email'] ?? currentEmail}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    label: buildRequiredLabel('Palavra-passe Atual'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(
                        () => obscureCurrent = !obscureCurrent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    label: buildRequiredLabel('Novo Email'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (newEmailController.text.isEmpty) {
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      try {
                        final supabase = Supabase.instance.client;
                        final user = supabase.auth.currentUser;

                        // Verificar password atual re-autenticando
                        await supabase.auth.signInWithPassword(
                          email: user!.email!,
                          password: currentPasswordController.text,
                        );

                        // Atualizar email diretamente via função SQL (sem email de confirmação)
                        await supabase.rpc(
                          'update_user_email',
                          params: {
                            'user_id': widget.userData['id'],
                            'new_email': newEmailController.text,
                          },
                        );

                        // Refrescar a sessão para que o currentUser reflita o novo email
                        await supabase.auth.refreshSession();

                        if (mounted) {
                          setState(() {
                            widget.userData['email'] = newEmailController.text;
                          });
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email atualizado com sucesso!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Erro ao atualizar: ${translateSupabaseError(e)}',
                              ),
                            ),
                          );
                        }
                      } finally {
                        setDialogState(() => isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirmar',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
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
      title: const Text(
        'Tema da Aplicação',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: const Text(
        'Escolha entre Claro, Escuro ou o Padrão do Sistema',
      ),
      trailing: DropdownButton<ThemeMode>(
        value: widget.settingsService.themeMode,
        onChanged: (ThemeMode? newMode) {
          if (newMode != null) {
            widget.settingsService.updateThemeMode(newMode);
          }
        },
        items: const [
          DropdownMenuItem(value: ThemeMode.system, child: Text('Sistema')),
          DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text('Escuro')),
        ],
      ),
    );
  }

  Widget _buildNotificationDropdown() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text(
        'Aviso de Eventos Próximos',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: const Text(
        'Destaque no botão e aviso visual de eventos muito próximos',
      ),
      trailing: DropdownButton<int>(
        value: widget.settingsService.eventNotificationTime,
        onChanged: (int? newMinutes) {
          if (newMinutes != null) {
            widget.settingsService.updateEventNotificationTime(newMinutes);
          }
        },
        items: const [
          DropdownMenuItem(value: 15, child: Text('15 Minutos')),
          DropdownMenuItem(value: 30, child: Text('30 Minutos')),
          DropdownMenuItem(value: 60, child: Text('1 Hora')),
          DropdownMenuItem(value: 120, child: Text('2 Horas')),
          DropdownMenuItem(value: 1440, child: Text('1 Dia')),
        ],
      ),
    );
  }

  Widget _buildLanguageDropdown() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text(
        'Idioma do Calendário',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: const Text('Selecione o idioma da agenda de cuidados'),
      trailing: DropdownButton<String>(
        value: widget.settingsService.calendarLanguage,
        onChanged: (String? newLang) {
          if (newLang != null) {
            widget.settingsService.updateCalendarLanguage(newLang);
          }
        },
        items: const [
          DropdownMenuItem(value: 'pt', child: Text('Português')),
          DropdownMenuItem(value: 'en', child: Text('English')),
        ],
      ),
    );
  }

  Widget _buildLowStockField() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text(
        'Alerta de Stock Baixo',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: const Text('Limite de unidades a partir do qual será avisado'),
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

  Widget _buildProfileCard() {
    final String nome = widget.userData['nome'] ?? widget.userData['email'] ?? 'Utilizador';
    final String email = widget.userData['email'] ?? '';
    final String tipo = widget.userData['tipo'] == 'cuidadora' ? 'Cuidador(a)' : 'Administrador';
    final String? fotoUrl = widget.userData['foto_url'];

    return Card(
      elevation: 0,
      color: Colors.amber.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.amber.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            GestureDetector(
              onTap: _pickProfileImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.amber.withOpacity(0.2),
                    backgroundImage: getAvatarProvider(fotoUrl),
                    child: fotoUrl == null || fotoUrl.isEmpty
                        ? const Icon(Icons.person, size: 40, color: Colors.amber)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      nome,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      email,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tipo,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64PhotoUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';

        final supabase = Supabase.instance.client;
        await supabase.from('users').update({
          'foto_url': base64PhotoUrl,
        }).eq('id', widget.userData['id']);

        setState(() {
          widget.userData['foto_url'] = base64PhotoUrl;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto de perfil atualizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar foto: ${translateSupabaseError(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
