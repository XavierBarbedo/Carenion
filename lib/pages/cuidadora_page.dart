import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../utils.dart';

class CuidadoraPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const CuidadoraPage({super.key, required this.userData});

  @override
  State<CuidadoraPage> createState() => _CuidadoraPageState();
}

class _CuidadoraPageState extends State<CuidadoraPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _familias = [];
  List<dynamic> _cuidadoras = [];
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final parentId = widget.userData['id'];

      // 1. Fetch parent's families
      final famRes = await _supabase
          .from('familias')
          .select()
          .eq('user_id', parentId)
          .order('nome');
      
      _familias = famRes;

      if (_familias.isNotEmpty) {
        final famIds = _familias.map((f) => f['id'] as int).toList();

        // 2. Fetch caregivers linked to these families
        final fcRes = await _supabase
            .from('familia_cuidadores')
            .select('*, users!inner(*)')
            .inFilter('familia_id', famIds);
        
        _cuidadoras = fcRes;

        final logsRes = await _supabase
            .from('cuidadora_logs')
            .select('*, users(nome, email, foto_url), familias(nome)')
            .inFilter('familia_id', famIds)
            .order('criado_em', ascending: false);
        
        _logs = logsRes;
      } else {
        _cuidadoras = [];
        _logs = [];
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados da cuidadora: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeleteCuidadora(dynamic cuidadora) async {
    final name = cuidadora['users']['nome'] ?? cuidadora['users']['email'] ?? 'Sem nome';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Cuidador(a)'),
        content: Text('Tem a certeza que deseja eliminar a conta de $name?\nEsta ação é irreversível.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final caregiverId = cuidadora['cuidadora_id'];

        // 1. Delete relations from familia_cuidadores
        await _supabase
            .from('familia_cuidadores')
            .delete()
            .eq('cuidadora_id', caregiverId);

        // 2. Delete user profile from users table
        await _supabase
            .from('users')
            .delete()
            .eq('id', caregiverId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conta de cuidador(a) eliminada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _fetchData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(translateSupabaseError(e)),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddCuidadoraDialog() {
    if (_familias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crie pelo menos uma família antes de registar um(a) cuidador(a).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final nomeController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    int? selectedFamiliaId = _familias.first['id'];
    bool isSaving = false;
    bool isObscure = true;
    final ImagePicker picker = ImagePicker();
    List<int>? fotoBytes;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Registar Cuidador(a)',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final pickedFile = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 512,
                      maxHeight: 512,
                      imageQuality: 75,
                    );
                    if (pickedFile != null) {
                      final bytes = await pickedFile.readAsBytes();
                      setDialogState(() {
                        fotoBytes = bytes;
                      });
                    }
                  },
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.amber.withOpacity(0.2),
                    backgroundImage: fotoBytes != null ? MemoryImage(Uint8List.fromList(fotoBytes!)) : null,
                    child: fotoBytes == null
                        ? const Icon(Icons.add_a_photo, size: 25, color: Colors.amber)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nomeController,
                  decoration: InputDecoration(
                    label: buildRequiredLabel('Nome Completo'),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    label: buildRequiredLabel('Email'),
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: isObscure,
                  decoration: InputDecoration(
                    label: buildRequiredLabel('Password (mín. 6 caract.)'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setDialogState(() => isObscure = !isObscure),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedFamiliaId,
                  decoration: InputDecoration(
                    label: buildRequiredLabel('Família Associada'),
                    prefixIcon: const Icon(Icons.family_restroom),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _familias
                      .map((f) => DropdownMenuItem<int>(
                            value: f['id'],
                            child: Text(f['nome']),
                          ))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedFamiliaId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      final nome = nomeController.text.trim();
                      final email = emailController.text.trim();
                      final password = passwordController.text.trim();

                      if (nome.isEmpty || email.isEmpty || password.isEmpty || selectedFamiliaId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor, preencha todos os campos.')),
                        );
                        return;
                      }

                      if (password.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('A password deve ter pelo menos 6 caracteres.')),
                        );
                        return;
                      }

                      setDialogState(() => isSaving = true);

                      try {
                        // Check if email already exists in public.users
                        final emailCheck = await _supabase
                            .from('users')
                            .select('id')
                            .eq('email', email)
                            .maybeSingle();

                        if (emailCheck != null) {
                          throw Exception('Este email já está registado no sistema.');
                        }

                        // 1. Create isolated temp client ONLY for auth.signUp
                        final tempClient = SupabaseClient(
                          dotenv.env['SUPABASE_URL'] ?? '',
                          dotenv.env['SUPABASE_ANON_KEY'] ?? '',
                          authOptions: AuthClientOptions(
                            authFlowType: AuthFlowType.implicit,
                            pkceAsyncStorage: EmptyStorage(),
                          ),
                        );

                        // 2. Sign up caregiver in auth.users
                        String newUserId;
                        try {
                          final authRes = await tempClient.auth.signUp(
                            email: email,
                            password: password,
                          );
                          if (authRes.user == null) {
                            throw Exception('Falha ao registar credenciais.');
                          }
                          newUserId = authRes.user!.id;
                        } catch (authErr) {
                          // If user exists in auth.users but not in public.users
                          // (orphan from a previous failed attempt), try to sign in
                          // to recover their ID
                          if (authErr.toString().contains('user_already_exists')) {
                            try {
                              final signInRes = await tempClient.auth.signInWithPassword(
                                email: email,
                                password: password,
                              );
                              if (signInRes.user == null) {
                                throw Exception(
                                  'Este email já tem conta de autenticação mas não foi possível recuperá-la. '
                                  'Elimine-a manualmente no painel do Supabase (Authentication > Users).',
                                );
                              }
                              newUserId = signInRes.user!.id;
                            } catch (signInErr) {
                              throw Exception(
                                'Este email já tem conta de autenticação criada anteriormente. '
                                'Elimine-a no painel do Supabase (Authentication > Users) e tente novamente.',
                              );
                            }
                          } else {
                            rethrow;
                          }
                        }

                        // 3. Use RPC (SECURITY DEFINER) to insert into users + familia_cuidadores
                        // This runs with elevated privileges, bypassing RLS
                        String? fotoUrl;
                        if (fotoBytes != null) {
                          fotoUrl = 'data:image/jpeg;base64,${base64Encode(fotoBytes!)}';
                        }
                        await _supabase.rpc('register_cuidadora', params: {
                          'p_user_id': newUserId,
                          'p_nome': nome,
                          'p_email': email,
                          'p_familia_id': selectedFamiliaId,
                          'p_foto_url': fotoUrl,
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cuidador(a) registado(a) com sucesso!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        _fetchData();
                      } catch (e) {
                        debugPrint('ERRO NO REGISTO: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        setDialogState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Registar'),
            ),
          ],
        ),
      ),
    );
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
              'Gestão de Cuidadores/as',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: 'Atualizar',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: Colors.amber.withOpacity(0.15),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'Cuidadores/as'),
            Tab(text: 'Log de Atividades'),
          ],
          labelColor: Colors.amber,
          unselectedLabelColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.amber.withOpacity(0.4)
              : Colors.amber.withOpacity(0.5),
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCuidadorasList(),
                _buildLogsList(),
              ],
            ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _showAddCuidadoraDialog,
              backgroundColor: Colors.amber,
              child: const Icon(Icons.person_add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildCuidadorasList() {
    if (_cuidadoras.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_ind_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Nenhum(a) cuidador(a) associado(a).',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _showAddCuidadoraDialog,
              child: const Text('Registar Cuidador(a)'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cuidadoras.length,
      itemBuilder: (context, index) {
        final fc = _cuidadoras[index];
        final user = fc['users'];
        final String nome = user['nome'] ?? 'Sem nome';
        final String email = user['email'] ?? 'Sem email';

        // Find associated family name
        final family = _familias.firstWhere(
          (f) => f['id'] == fc['familia_id'],
          orElse: () => {'nome': 'Desconhecida'},
        );
        final String familyName = family['nome'];

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: user['foto_url'] != null && user['foto_url'].toString().isNotEmpty
                ? CircleAvatar(
                    backgroundImage: getAvatarProvider(user['foto_url']),
                    backgroundColor: Colors.amber.withOpacity(0.2),
                  )
                : CircleAvatar(
                    backgroundColor: Colors.amber.withOpacity(0.2),
                    child: const Icon(Icons.person, color: Colors.amber),
                  ),
            title: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                nome,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(email),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.family_restroom, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Família: $familyName',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _confirmDeleteCuidadora(fc),
              tooltip: 'Eliminar conta',
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogsList() {
    if (_logs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Sem atividades registadas.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        final String action = log['acao'] ?? '';
        final String entity = log['entidade'] ?? '';
        final String details = log['detalhes'] ?? '';
        final String criadoEm = log['criado_em'] ?? '';
        
        final user = log['users'];
        final String userName = user != null ? (user['nome'] ?? user['email'] ?? 'Cuidador(a)') : 'Cuidador(a)';

        final family = log['familias'];
        final String familyName = family != null ? (family['nome'] ?? 'Família') : 'Família';

        DateTime? parsedTime = DateTime.tryParse(criadoEm);
        String timeStr = parsedTime != null 
            ? DateFormat('dd/MM/yyyy HH:mm').format(parsedTime) 
            : criadoEm;

        IconData icon;
        Color color;
        String actionVerb;

        switch (action.toLowerCase()) {
          case 'criar':
            icon = Icons.add_circle_outline;
            color = Colors.green;
            actionVerb = 'criou';
            break;
          case 'editar':
            icon = Icons.edit_outlined;
            color = Colors.blue;
            actionVerb = 'editou';
            break;
          case 'eliminar':
            icon = Icons.delete_outline;
            color = Colors.redAccent;
            actionVerb = 'eliminou';
            break;
          default:
            icon = Icons.info_outline;
            color = Colors.grey;
            actionVerb = 'realizou ação em';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: getAvatarProvider(user != null ? user['foto_url'] : null),
                      backgroundColor: color.withOpacity(0.1),
                      child: user == null || user['foto_url'] == null || user['foto_url'].toString().isEmpty
                          ? Icon(icon, color: color, size: 18)
                          : null,
                    ),
                    if (user != null && user['foto_url'] != null && user['foto_url'].toString().isNotEmpty)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 1),
                          ),
                          child: Icon(icon, color: color, size: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white 
                                : Colors.black87,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: userName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: ' $actionVerb o/a '),
                            TextSpan(
                              text: entity,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: ' na '),
                            TextSpan(
                              text: familyName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (details.isNotEmpty) ...[
                        Text(
                          details,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? Colors.white70 
                                : Colors.black54,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        timeStr,
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Custom storage to isolate the temporary client's authentication session in memory
class EmptyStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) async => null;

  @override
  Future<void> setItem({required String key, required String value}) async {}

  @override
  Future<void> removeItem({required String key}) async {}
}
