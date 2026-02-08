import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String hashPassword(String password) {
  final bytes = utf8.encode(password); // converte para bytes
  final digest = sha256.convert(bytes); // gera hash SHA-256
  return digest.toString(); // retorna como string hexadecimal
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://ywystlcfdcyhudjgxgfe.supabase.co',
    anonKey: 'sb_publishable_HutjQsw7m-WR8n_DEJsHnw_LwFjZUPa',
  );

  runApp(const CarenionApp());
}

class CarenionApp extends StatelessWidget {
  const CarenionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carenion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isObscure = true;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor preencha todos os campos')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final hashedPassword = hashPassword(_passwordController.text);

      // Consulta à tabela 'users'
      final response = await supabase
          .from('users')
          .select()
          .eq('email', _emailController.text)
          .maybeSingle(); 

      if (response == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilizador não encontrado')),
        );
        return;
      }

      final user = response;
      
      bool passwordMatch = user['password'] == hashedPassword;

      if (!passwordMatch) {
        passwordMatch = user['password'] == _passwordController.text;
      }

      if (passwordMatch) {
         if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login efetuado com sucesso!')),
        );
        // Navegar para a próxima tela
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(userData: user),
          ),
        );
      } else {
         if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password incorreta')),
        );
      }
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao conectar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo + Nome do App
              Column(
                children: [
                   Image.asset(
                    'images/carenion_Icon-removebg-preview.png',
                    height: 120,
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 60),
                    child: const Text(
                      'Carenion',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),

              // Campo de email
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Campo de password
              TextField(
                controller: _passwordController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () {
                      setState(() {
                        _isObscure = !_isObscure;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Botão de login
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Entrar', style: TextStyle(fontSize: 18)),
                ),
              ),

              const SizedBox(height: 20),

              // Link para criar conta
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Não tens conta? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SignUpPage()),
                      );
                    },
                    child: const Text(
                      "Criar conta",
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordObscure = true;
  bool _isConfirmPasswordObscure = true;

  Future<void> _signUp() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor preencha todos os campos')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As passwords não coincidem')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final hashedPassword = hashPassword(_passwordController.text);

      // Inserir novo utilizador
      await supabase.from('users').insert({
        'email': _emailController.text,
        'password': hashedPassword,
        'tipo': 'cuidador', // Default como pedido
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta criada com sucesso!')),
      );
      Navigator.pop(context); // Voltar ao login

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar conta: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Criar conta"),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: _isPasswordObscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () {
                    setState(() {
                      _isPasswordObscure = !_isPasswordObscure;
                    });
                  },
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _isConfirmPasswordObscure,
              decoration: InputDecoration(
                labelText: 'Confirmar Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_isConfirmPasswordObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordObscure = !_isConfirmPasswordObscure;
                    });
                  },
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _signUp,
                 child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Criar conta', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const HomePage({super.key, required this.userData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardPage(userData: widget.userData),
      IdososPage(userData: widget.userData),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Idosos',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber,
        onTap: _onItemTapped,
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  final Map<String, dynamic> userData;
  const DashboardPage({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carenion'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medical_services_outlined, size: 100, color: Colors.amber),
            const SizedBox(height: 20),
            Text(
              'Bem-vindo, ${userData['nome'] ?? 'Utilizador'}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Aqui podes gerir a saúde e o dia a dia dos teus idosos de forma simples e organizada.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IdososPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const IdososPage({super.key, required this.userData});

  @override
  State<IdososPage> createState() => _IdososPageState();
}

class _IdososPageState extends State<IdososPage> {
  List<dynamic> _idosos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchIdosos();
  }

  Future<void> _fetchIdosos() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      
      // Busca os IDs dos idosos associados a este utilizador
      final userIdososResponse = await supabase
          .from('user_idoso')
          .select('idoso_id')
          .eq('user_id', widget.userData['id']);

      if (userIdososResponse is List && userIdososResponse.isNotEmpty) {
        final idosoIds = userIdososResponse.map((ui) => ui['idoso_id']).toList();
        
        // Busca os detalhes dos idosos
        final idososResponse = await supabase
            .from('idosos')
            .select()
            .inFilter('id', idosoIds);
        
        setState(() {
          _idosos = idososResponse;
        });
      } else {
        setState(() {
          _idosos = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar idosos: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Idosos'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _idosos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Nenhum idoso registado', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _idosos.length,
                  itemBuilder: (context, index) {
                    final idoso = _idosos[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.withOpacity(0.2),
                          child: const Icon(Icons.person, color: Colors.amber),
                        ),
                        title: Text(idoso['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(idoso['morada'] ?? 'Sem morada'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => IdosoDetailsPage(idosoData: idoso, userId: widget.userData['id']),
                            ),
                          );
                          if (result == true) {
                            _fetchIdosos();
                          }
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RegisterIdosoPage(userId: widget.userData['id']),
            ),
          );
          if (result == true) {
            _fetchIdosos();
          }
        },
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class RegisterIdosoPage extends StatefulWidget {
  final String userId;
  const RegisterIdosoPage({super.key, required this.userId});

  @override
  State<RegisterIdosoPage> createState() => _RegisterIdosoPageState();
}

class _RegisterIdosoPageState extends State<RegisterIdosoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _dataNascController = TextEditingController();
  final _nifController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _moradaController = TextEditingController();
  final _patologiasController = TextEditingController();
  final _obsController = TextEditingController();
  
  String _sexo = 'M';
  bool _isLoading = false;

  Future<void> _registerIdoso() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Debug log to verify the userId being sent
      print('DEBUG: Iniciando registo para userId: ${widget.userId}');

      // 1. Inserir na tabela 'idosos'
      final idosoResponse = await supabase.from('idosos').insert({
        'nome': _nomeController.text,
        'data_nascimento': _dataNascController.text,
        'sexo': _sexo,
        'nif': _nifController.text,
        'telefone': _telefoneController.text,
        'morada': _moradaController.text,
        'patologias': _patologiasController.text,
        'observacoes': _obsController.text,
        'criado_em': DateTime.now().toIso8601String(),
      }).select().single();

      final idosoId = idosoResponse['id'];
      print('DEBUG: Idoso criado com ID: $idosoId');

      // 2. Criar relação na tabela 'user_idoso'
      await supabase.from('user_idoso').insert({
        'user_id': widget.userId,
        'idoso_id': idosoId,
        'papel': 'cuidador', // Ou outro papel padrão
        'criado_em': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Idoso registado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);

    } catch (e) {
      print('DEBUG: Erro detalhado ao registar idoso: $e');
      if (mounted) {
        String errorMessage = 'Erro ao registar idoso';
        if (e.toString().contains('fk_user')) {
          errorMessage = 'Erro de permissão ou utilizador inválido (FK violation)';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorMessage: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registar Idoso'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(_nomeController, 'Nome Completo', Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField(_dataNascController, 'Data de Nascimento (AAAA-MM-DD)', Icons.calendar_today_outlined),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _sexo,
                decoration: InputDecoration(
                  labelText: 'Sexo',
                  prefixIcon: const Icon(Icons.wc_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Masculino')),
                  DropdownMenuItem(value: 'F', child: Text('Feminino')),
                  DropdownMenuItem(value: 'O', child: Text('Outro')),
                ],
                onChanged: (val) => setState(() => _sexo = val!),
              ),
              const SizedBox(height: 16),
              _buildTextField(_nifController, 'NIF', Icons.badge_outlined),
              const SizedBox(height: 16),
              _buildTextField(_telefoneController, 'Telefone', Icons.phone_outlined),
              const SizedBox(height: 16),
              _buildTextField(_moradaController, 'Morada', Icons.home_outlined),
              const SizedBox(height: 16),
              _buildTextField(_patologiasController, 'Patologias/Doenças', Icons.medical_information_outlined, maxLines: 2),
              const SizedBox(height: 16),
              _buildTextField(_obsController, 'Observações', Icons.note_add_outlined, maxLines: 3),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _registerIdoso,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar Registo', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
    );
  }
}

class IdosoDetailsPage extends StatelessWidget {
  final Map<String, dynamic> idosoData;
  final String userId;
  const IdosoDetailsPage({super.key, required this.idosoData, required this.userId});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Registo'),
        content: Text('Tem a certeza que deseja eliminar o registo de ${idosoData['nome']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final supabase = Supabase.instance.client;
        
        // Deletar relação primeiro (ou deixar o cascade do banco fazer)
        await supabase.from('user_idoso').delete().eq('idoso_id', idosoData['id']);
        // Deletar o idoso
        await supabase.from('idosos').delete().eq('id', idosoData['id']);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registo eliminado com sucesso'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao eliminar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(idosoData['nome'] ?? 'Detalhes'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditIdosoPage(idosoData: idosoData),
                ),
              );
              if (result == true) {
                Navigator.pop(context, true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailItem(Icons.person_outline, 'Nome', idosoData['nome']),
            _buildDetailItem(Icons.calendar_today_outlined, 'Data de Nascimento', idosoData['data_nascimento']),
            _buildDetailItem(Icons.wc_outlined, 'Sexo', idosoData['sexo'] == 'M' ? 'Masculino' : idosoData['sexo'] == 'F' ? 'Feminino' : 'Outro'),
            _buildDetailItem(Icons.badge_outlined, 'NIF', idosoData['nif']),
            _buildDetailItem(Icons.phone_outlined, 'Telefone', idosoData['telefone']),
            _buildDetailItem(Icons.home_outlined, 'Morada', idosoData['morada']),
            _buildDetailItem(Icons.medical_information_outlined, 'Patologias', idosoData['patologias']),
            _buildDetailItem(Icons.note_add_outlined, 'Observações', idosoData['observacoes']),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.amber, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(value?.toString() ?? 'Não preenchido', style: const TextStyle(fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EditIdosoPage extends StatefulWidget {
  final Map<String, dynamic> idosoData;
  const EditIdosoPage({super.key, required this.idosoData});

  @override
  State<EditIdosoPage> createState() => _EditIdosoPageState();
}

class _EditIdosoPageState extends State<EditIdosoPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  late TextEditingController _dataNascController;
  late TextEditingController _nifController;
  late TextEditingController _telefoneController;
  late TextEditingController _moradaController;
  late TextEditingController _patologiasController;
  late TextEditingController _obsController;
  
  late String _sexo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.idosoData['nome']);
    _dataNascController = TextEditingController(text: widget.idosoData['data_nascimento']);
    _nifController = TextEditingController(text: widget.idosoData['nif']);
    _telefoneController = TextEditingController(text: widget.idosoData['telefone']);
    _moradaController = TextEditingController(text: widget.idosoData['morada']);
    _patologiasController = TextEditingController(text: widget.idosoData['patologias']);
    _obsController = TextEditingController(text: widget.idosoData['observacoes']);
    _sexo = widget.idosoData['sexo'] ?? 'M';
  }

  Future<void> _updateIdoso() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      await supabase.from('idosos').update({
        'nome': _nomeController.text,
        'data_nascimento': _dataNascController.text,
        'sexo': _sexo,
        'nif': _nifController.text,
        'telefone': _telefoneController.text,
        'morada': _moradaController.text,
        'patologias': _patologiasController.text,
        'observacoes': _obsController.text,
      }).eq('id', widget.idosoData['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados atualizados com sucesso!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Idoso'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(_nomeController, 'Nome Completo', Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField(_dataNascController, 'Data de Nascimento (AAAA-MM-DD)', Icons.calendar_today_outlined),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _sexo,
                decoration: InputDecoration(
                  labelText: 'Sexo',
                  prefixIcon: const Icon(Icons.wc_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Masculino')),
                  DropdownMenuItem(value: 'F', child: Text('Feminino')),
                  DropdownMenuItem(value: 'O', child: Text('Outro')),
                ],
                onChanged: (val) => setState(() => _sexo = val!),
              ),
              const SizedBox(height: 16),
              _buildTextField(_nifController, 'NIF', Icons.badge_outlined),
              const SizedBox(height: 16),
              _buildTextField(_telefoneController, 'Telefone', Icons.phone_outlined),
              const SizedBox(height: 16),
              _buildTextField(_moradaController, 'Morada', Icons.home_outlined),
              const SizedBox(height: 16),
              _buildTextField(_patologiasController, 'Patologias/Doenças', Icons.medical_information_outlined, maxLines: 2),
              const SizedBox(height: 16),
              _buildTextField(_obsController, 'Observações', Icons.note_add_outlined, maxLines: 3),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _updateIdoso,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Salvar Alterações', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
    );
  }
}

