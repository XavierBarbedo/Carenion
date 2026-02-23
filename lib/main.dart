import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

const String MED_API_URL = 'https://clinicaltables.nlm.nih.gov/api/rxterms/v3/search?terms=';

const List<String> PORTUGUESE_MEDS = [
  'Ben-u-ron', 'Brufen', 'Nolotil', 'Buscopan', 'Maxilase', 'Guronsan', 'Nimed',
  'Voltaren', 'Aspirina', 'Pantoprazol', 'Omeprazol', 'Fenistil', 'Daflon',
  'Leponex', 'Xanax', 'Victan', 'Stilnox', 'Zyrtec', 'Aerius', 'Ventilan',
  'Clamoxyl', 'Augmentin', 'Zinnat', 'Prioftal', 'Lotesoft', 'Vigamox',
  'Atarax', 'Kwells', 'Tussilene', 'Bisolvon', 'Strepsils', 'Mebocaína',
  'Ilvico', 'Cê-Gripe', 'Antigriphine', 'Griponal', 'Melhoral', 'Aspegic',
  'Cartilogen', 'Voltaren Emulgel', 'Fenistil Gel', 'Bepanthene', 'Halibut',
  'Lansoprazol', 'Esomeprazol', 'Simvastatina', 'Atorvastatina', 'Rosuvastatina',
  'Amlodipina', 'Ramipril', 'Losartan', 'Valsartan', 'Eutirox', 'Metformina',
  'Januvia', 'Victoza', 'Ozempic', 'Trulicity', 'Jardiance', 'Forxiga'
];

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
      MedicamentosPage(userData: widget.userData),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.medication_outlined),
            activeIcon: Icon(Icons.medication),
            label: 'Medicação',
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
      
      // Busca todas as famílias primeiro
      final familiasResponse = await supabase
          .from('familias')
          .select()
          .order('nome');
      
      final familias = List<Map<String, dynamic>>.from(familiasResponse);

      // Busca todos os idosos
      final userIdososResponse = await supabase
          .from('user_idoso')
          .select('idoso_id')
          .eq('user_id', widget.userData['id']);

      if (userIdososResponse is List && userIdososResponse.isNotEmpty) {
        final idosoIds = userIdososResponse.map((ui) => ui['idoso_id']).toList();
        
        final idososResponse = await supabase
            .from('idosos')
            .select()
            .inFilter('id', idosoIds);
        
        final idosos = List<Map<String, dynamic>>.from(idososResponse);

        // Mapear idosos para as famílias
        for (var familia in familias) {
          familia['idosos'] = idosos.where((i) => i['familia_id'] == familia['id']).toList();
        }
        
        // Famílias sem idosos aparecerão também.
        // Idosos sem família (se houver algum órfão) - o requisito diz que está sempre associado.
      } else {
        for (var familia in familias) {
          familia['idosos'] = [];
        }
      }

      setState(() {
        _familias = familias;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> _familias = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Famílias e Idosos'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.family_restroom),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FamiliasPage()),
              );
              _fetchIdosos();
            },
            tooltip: 'Gerir Famílias',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _familias.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Nenhuma família registada', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => FamiliasPage()),
                          );
                          _fetchIdosos();
                        },
                        child: const Text('Registar Família'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _familias.length,
                  itemBuilder: (context, index) {
                    final familia = _familias[index];
                    final listIdosos = familia['idosos'] as List<dynamic>? ?? [];
                    
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.withOpacity(0.2),
                          child: const Icon(Icons.family_restroom, color: Colors.amber),
                        ),
                        title: Text(familia['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${listIdosos.length} idosos associados'),
                        children: [
                          if (listIdosos.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Nenhum idoso nesta família', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                            ),
                          ...listIdosos.map((idoso) => ListTile(
                            leading: const Icon(Icons.person, color: Colors.amber),
                            title: Text(idoso['nome'] ?? 'Sem nome'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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
                          )).toList(),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RegisterIdosoPage(userId: widget.userData['id'], initialFamiliaId: familia['id']),
                                  ),
                                );
                                if (result == true) _fetchIdosos();
                              },
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('Adicionar Idoso a esta Família'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_familias.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Por favor, registe primeiro uma família')),
            );
            return;
          }
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RegisterIdosoPage(userId: widget.userData['id']),
            ),
          );
          _fetchIdosos();
        },
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class RegisterIdosoPage extends StatefulWidget {
  final String userId;
  final int? initialFamiliaId;
  const RegisterIdosoPage({super.key, required this.userId, this.initialFamiliaId});

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
  int? _selectedFamiliaId;
  List<dynamic> _familias = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedFamiliaId = widget.initialFamiliaId;
    _fetchFamilias();
  }

  Future<void> _fetchFamilias() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('familias').select().order('nome');
      setState(() {
        _familias = response;
        if (_selectedFamiliaId == null && _familias.isNotEmpty) {
          // opcional: auto selecionar a primeira se não houver inicial
        }
      });
    } catch (e) {
      print('Erro ao carregar famílias: $e');
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 70)), // Idoso
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Selecione a data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (picked != null) {
      setState(() {
        _dataNascController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

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
        'familia_id': _selectedFamiliaId,
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
              InkWell(
                onTap: _pickDate,
                child: IgnorePointer(
                  child: _buildTextField(_dataNascController, 'Data de Nascimento', Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedFamiliaId,
                decoration: InputDecoration(
                  labelText: 'Família',
                  prefixIcon: const Icon(Icons.family_restroom_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _familias.map((f) => DropdownMenuItem<int>(
                  value: f['id'],
                  child: Text(f['nome'] ?? 'Sem nome'),
                )).toList(),
                onChanged: (val) => setState(() => _selectedFamiliaId = val),
                validator: (value) => value == null ? 'Seleccione uma família' : null,
              ),
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
              _buildTextField(_nifController, 'NIF', Icons.badge_outlined, hintText: 'Ex: 123456789'),
              const SizedBox(height: 16),
              _buildTextField(_telefoneController, 'Telefone', Icons.phone_outlined, hintText: 'Ex: 912345678'),
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, String? hintText}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
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
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageMedicacoesPage(idosoData: idosoData),
                    ),
                  );
                },
                icon: const Icon(Icons.medication),
                label: const Text('Gerir Medicação', style: TextStyle(fontSize: 18)),
              ),
            ),
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
  int? _selectedFamiliaId;
  List<dynamic> _familias = [];
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
    _selectedFamiliaId = widget.idosoData['familia_id'];
    _fetchFamilias();
  }

  Future<void> _fetchFamilias() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('familias').select().order('nome');
      setState(() {
        _familias = response;
      });
    } catch (e) {
      print('Erro ao carregar famílias: $e');
    }
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 70));
    try {
      if (_dataNascController.text.isNotEmpty) {
        initial = DateTime.parse(_dataNascController.text);
      }
    } catch (_) {}

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Selecione a data de nascimento',
    );
    if (picked != null) {
      setState(() {
        _dataNascController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
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
        'familia_id': _selectedFamiliaId,
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
              InkWell(
                onTap: _pickDate,
                child: IgnorePointer(
                  child: _buildTextField(_dataNascController, 'Data de Nascimento', Icons.calendar_today_outlined),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedFamiliaId,
                decoration: InputDecoration(
                  labelText: 'Família',
                  prefixIcon: const Icon(Icons.family_restroom_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _familias.map((f) => DropdownMenuItem<int>(
                  value: f['id'],
                  child: Text(f['nome'] ?? 'Sem nome'),
                )).toList(),
                onChanged: (val) => setState(() => _selectedFamiliaId = val),
                validator: (value) => value == null ? 'Seleccione uma família' : null,
              ),
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
              _buildTextField(_nifController, 'NIF', Icons.badge_outlined, hintText: 'Ex: 123456789'),
              const SizedBox(height: 16),
              _buildTextField(_telefoneController, 'Telefone', Icons.phone_outlined, hintText: 'Ex: 912345678'),
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1, String? hintText}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
    );
  }
}

class FamiliasPage extends StatefulWidget {
  const FamiliasPage({super.key});

  @override
  State<FamiliasPage> createState() => _FamiliasPageState();
}

class _FamiliasPageState extends State<FamiliasPage> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _familias = [];
  bool _isLoading = true;

  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _fetchFamilias();
  }

  Future<void> _fetchFamilias() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.from('familias').select().order('nome');
      setState(() => _familias = response);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao carregar famílias: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addFamilia() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova Família'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nome da Família'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await _supabase.from('familias').insert({'nome': controller.text});
                  _hasChanges = true;
                  if (mounted) Navigator.pop(context);
                  _fetchFamilias();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao adicionar: $e')));
                  }
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _editFamilia(Map<String, dynamic> familia) async {
    final controller = TextEditingController(text: familia['nome']);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Família'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nome da Família'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await _supabase.from('familias').update({'nome': controller.text}).eq('id', familia['id']);
                  _hasChanges = true;
                  if (mounted) Navigator.pop(context);
                  _fetchFamilias();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao editar: $e')));
                  }
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFamilia(dynamic familia) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Família'),
        content: Text('Tem a certeza que deseja eliminar a família ${familia['nome']}?'),
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
        final idososResponse = await _supabase.from('idosos').select().eq('familia_id', familia['id']);
        if (idososResponse.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Não é possível eliminar uma família com idosos associados.')),
            );
          }
          return;
        }

        await _supabase.from('familias').delete().eq('id', familia['id']);
        _hasChanges = true;
        _fetchFamilias();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao eliminar: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerir Famílias'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _hasChanges),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _familias.isEmpty
              ? const Center(child: Text('Nenhuma família registada.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _familias.length,
                  itemBuilder: (context, index) {
                    final familia = _familias[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.family_restroom, color: Colors.amber),
                        title: Text(familia['nome'] ?? 'Sem nome'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              onPressed: () => _editFamilia(familia),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteFamilia(familia),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFamilia,
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class MedicamentosPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const MedicamentosPage({super.key, required this.userData});

  @override
  State<MedicamentosPage> createState() => _MedicamentosPageState();
}

class _MedicamentosPageState extends State<MedicamentosPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _tomasSemana = [];
  List<dynamic> _stockFamilia = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final familiasRes = await _supabase.from('familias').select().order('nome');
      final idososRes = await _supabase.from('idosos').select('*, medicacoes(*)').order('nome');
      
      setState(() {
        _stockFamilia = (familiasRes as List).map((f) {
          f['idosos'] = (idososRes as List).where((i) => i['familia_id'] == f['id']).toList();
          return f;
        }).toList();
      });
      
      _fetchTomasSemana();
    } catch (e) {
      debugPrint('Erro ao carregar dados de medicação: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTomasSemana() async {
    try {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().substring(0, 10);
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      
      final medsRes = await _supabase.from('medicacoes').select('*, idosos(nome)');
      
      if (medsRes is List && medsRes.isNotEmpty) {
        final tomasRes = await _supabase.from('medicacao_tomas')
            .select()
            .filter('medicacao_id', 'in', medsRes.map((m) => m['id']).toList())
            .gte('data', startOfWeek.toIso8601String().substring(0, 10))
            .lte('data', startOfWeek.add(const Duration(days: 6)).toIso8601String().substring(0, 10));

        List<Map<String, dynamic>> projection = [];
        
        // Gerar entradas para cada dia da semana (Segunda a Domingo)
        for (int i = 0; i < 7; i++) {
          final dayDate = startOfWeek.add(Duration(days: i));
          final dayStr = dayDate.toIso8601String().substring(0, 10);
          final isFuture = dayDate.isAfter(now) && dayStr != todayStr;
          final isToday = dayStr == todayStr;

          for (var med in medsRes) {
            // Lógica simplificada: Se a medicação existe, assume-se que é diária para a projeção
            // No futuro, isto pode ser filtrado por dias_da_semana na DB
            final checkToma = (tomasRes as List).any((t) => t['medicacao_id'] == med['id'] && t['data'] == dayStr);
            
            projection.add({
              ...med,
              'data_toma': dayStr,
              'is_today': isToday,
              'is_future': isFuture,
              'tomada': checkToma,
              'day_label': _getDayLabel(dayDate.weekday),
              'date_label': '${dayDate.day}/${dayDate.month}',
            });
          }
        }

        setState(() {
          _tomasSemana = projection;
        });
      } else {
        setState(() => _tomasSemana = []);
      }
    } catch (e) {
      debugPrint('Erro ao carregar tomas: $e');
    }
  }

  String _getDayLabel(int weekday) {
    switch (weekday) {
      case 1: return 'Segunda';
      case 2: return 'Terça';
      case 3: return 'Quarta';
      case 4: return 'Quinta';
      case 5: return 'Sexta';
      case 6: return 'Sábado';
      case 7: return 'Domingo';
      default: return '';
    }
  }

  Future<void> _marcarTomado(dynamic med) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      
      // 1. Logar a toma
      await _supabase.from('medicacao_tomas').insert({
        'medicacao_id': med['id'],
        'data': today,
        'quantidade_tomada': 1,
      });

      // 2. Atualizar stock
      if (med['stock_atual'] != null && med['stock_atual'] > 0) {
        await _supabase.from('medicacoes').update({
          'stock_atual': med['stock_atual'] - 1
        }).eq('id', med['id']);
      }

      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medicação marcada como tomada!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao marcar como tomada: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Medicação'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tomas da Semana'),
            Tab(text: 'Stock por Família'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTomasSemana(),
          _buildStockFamilia(),
        ],
      ),
    );
  }

  Widget _buildTomasSemana() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.amber));
    if (_tomasSemana.isEmpty) {
      return const Center(child: Text('Nenhuma medicação agendada para esta semana.', style: TextStyle(color: Colors.grey)));
    }

    // Agrupar por data
    Map<String, List<dynamic>> groupedByDate = {};
    for (var item in _tomasSemana) {
      final key = '${item['day_label']} (${item['date_label']})';
      groupedByDate.putIfAbsent(key, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: groupedByDate.keys.map((dateKey) {
        final items = groupedByDate[dateKey]!;
        final isToday = items.any((i) => i['is_today']);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isToday ? Colors.amber[800] : Colors.blueGrey,
                ),
              ),
            ),
            ...items.map((item) {
              final idosoNome = item['idosos']?['nome'] ?? 'Desconhecido';
              final isFuture = item['is_future'];
              
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: isFuture ? Colors.grey[50] : null,
                child: ListTile(
                  leading: Icon(
                    Icons.medical_services,
                    color: item['tomada'] ? Colors.green : (isFuture ? Colors.grey : Colors.amber),
                  ),
                  title: Text(item['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Para: $idosoNome\n${item['regularidade']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.blueGrey, size: 20),
                        onPressed: () async {
                          final idosoRes = await _supabase.from('idosos').select().eq('id', item['idoso_id']).single();
                          if (mounted) {
                            await Navigator.push(context, MaterialPageRoute(builder: (context) => ManageMedicacoesPage(idosoData: idosoRes)));
                            _fetchData();
                          }
                        },
                      ),
                      if (item['tomada'])
                        const Icon(Icons.check_circle, color: Colors.green, size: 30)
                      else if (isFuture)
                        const Icon(Icons.schedule, color: Colors.grey, size: 30) // Ícone de relógio para futuro
                      else
                        IconButton(
                          icon: const Icon(Icons.circle_outlined, color: Colors.grey, size: 30),
                          onPressed: () => _marcarTomado(item),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildStockFamilia() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.amber));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _stockFamilia.length,
      itemBuilder: (context, index) {
        final familia = _stockFamilia[index];
        final idosos = familia['idosos'] as List;
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: const Icon(Icons.family_restroom, color: Colors.amber),
            title: Text(familia['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${idosos.length} idosos associados'),
            children: idosos.isEmpty 
              ? [const Padding(padding: EdgeInsets.all(16), child: Text('Sem idosos registados.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))]
              : idosos.map((idoso) {
                  final meds = idoso['medicacoes'] as List;
                  return ExpansionTile(
                    title: Text(idoso['nome'] ?? 'Sem nome'),
                    subtitle: Text('${meds.length} medicamentos'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (context) => ManageMedicacoesPage(idosoData: idoso)));
                            _fetchData();
                          },
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    children: meds.isEmpty 
                      ? [const ListTile(title: Text('Sem medicação registada', style: TextStyle(fontSize: 13, color: Colors.grey)))]
                      : meds.map((m) => ListTile(
                          title: Text(m['nome']),
                          subtitle: Text('Regularidade: ${m['regularidade']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (m['stock_atual'] ?? 0) < 5 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('Stock: ${m['stock_atual'] ?? 0}', style: TextStyle(fontWeight: FontWeight.bold, color: (m['stock_atual'] ?? 0) < 5 ? Colors.red : Colors.green)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                tooltip: 'Editar',
                                onPressed: () async {
                                  await Navigator.push(context, MaterialPageRoute(builder: (context) => ManageMedicacoesPage(idosoData: idoso)));
                                  _fetchData();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                tooltip: 'Eliminar',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Eliminar Medicação'),
                                      content: Text('Tem a certeza que deseja eliminar ${m['nome']}?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    try {
                                      await _supabase.from('medicacoes').delete().eq('id', m['id']);
                                      _fetchData();
                                    } catch (e) {
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao eliminar: $e')));
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        )).toList(),
                  );
                }).toList(),
          ),
        );
      },
    );
  }
}

class ManageMedicacoesPage extends StatefulWidget {
  final Map<String, dynamic> idosoData;
  const ManageMedicacoesPage({super.key, required this.idosoData});

  @override
  State<ManageMedicacoesPage> createState() => _ManageMedicacoesPageState();
}

class _ManageMedicacoesPageState extends State<ManageMedicacoesPage> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _medicacoes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMedicacoes();
  }

  Future<void> _fetchMedicacoes() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase.from('medicacoes').select().eq('idoso_id', widget.idosoData['id']);
      setState(() => _medicacoes = res);
    } catch (e) {
      debugPrint('Erro ao carregar medicações: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<String>> _searchMedication(String query) async {
    if (query.length < 2) return [];
    
    // 1. Pesquisa local (Marcas Portuguesas)
    final localResults = PORTUGUESE_MEDS
        .where((m) => m.toLowerCase().contains(query.toLowerCase()))
        .toList();

    try {
      // 2. Pesquisa na API (Científica/Internacional)
      final response = await http.get(Uri.parse('$MED_API_URL$query'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final apiResults = List<String>.from(data[1]);
        
        // 3. Mesclar resultados (evitar duplicados)
        final combined = [...localResults];
        for (var res in apiResults) {
          if (!combined.any((l) => l.toLowerCase() == res.toLowerCase())) {
            combined.add(res);
          }
        }
        return combined.take(20).toList(); // Limitar a 20 sugestões
      }
    } catch (e) {
      debugPrint('Erro na pesquisa API: $e');
    }
    
    return localResults;
  }

  Future<void> _addOrEditMed([Map<String, dynamic>? med]) async {
    final nomeController = TextEditingController(text: med?['nome']);
    final doseController = TextEditingController(text: med?['quantidade']); 
    final List<String> regularidadeOptions = [
      '1 vez ao dia',
      '2 vezes ao dia',
      '3 vezes ao dia',
      '4 vezes ao dia',
      '5 vezes ao dia',
      '6 vezes ao dia',
    ];
    
    String? selectedRegularidade = med?['regularidade'];
    // Se o valor da DB não estiver nas novas opções (ex: "Todos os dias"), default para null
    if (!regularidadeOptions.contains(selectedRegularidade)) {
      selectedRegularidade = null;
    }

    final stockController = TextEditingController(text: med?['stock_atual']?.toString() ?? '30');
    final obsController = TextEditingController(text: med?['observacoes']);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // Use StatefulBuilder for dropdown updates
        builder: (context, setDialogState) => AlertDialog(
          title: Text(med == null ? 'Nova Medicação' : 'Editar Medicação'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: med?['nome'] ?? ''),
                  optionsBuilder: (TextEditingValue textEditingValue) => _searchMedication(textEditingValue.text),
                  onSelected: (String selection) => nomeController.text = selection,
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    controller.addListener(() => nomeController.text = controller.text);
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Medicamento',
                        prefixIcon: Icon(Icons.medication),
                        suffixIcon: Icon(Icons.search, size: 20),
                      ),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.7,
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                title: Text(option),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: doseController, decoration: const InputDecoration(labelText: 'Dose (ex: 1 comprimido)', prefixIcon: Icon(Icons.science))),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedRegularidade,
                  decoration: const InputDecoration(labelText: 'Regularidade', prefixIcon: Icon(Icons.repeat)),
                  items: regularidadeOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                  onChanged: (val) => setDialogState(() => selectedRegularidade = val),
                ),
                const SizedBox(height: 8),
                TextField(controller: stockController, decoration: const InputDecoration(labelText: 'Stock Atual', prefixIcon: Icon(Icons.inventory)), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(
                  controller: obsController,
                  decoration: const InputDecoration(labelText: 'Observações', prefixIcon: Icon(Icons.note_alt_outlined)),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.white),
              onPressed: () async {
                if (nomeController.text.isEmpty) return;
                final data = {
                  'idoso_id': widget.idosoData['id'],
                  'nome': nomeController.text,
                  'quantidade': doseController.text,
                  'regularidade': selectedRegularidade,
                  'observacoes': obsController.text,
                  'stock_atual': int.tryParse(stockController.text) ?? 0,
                };
                try {
                  if (med == null) {
                    await _supabase.from('medicacoes').insert(data);
                  } else {
                    await _supabase.from('medicacoes').update(data).eq('id', med['id']);
                  }
                  if (mounted) Navigator.pop(context);
                  _fetchMedicacoes();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                }
              },
              child: const Text('Guardar'),
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
        title: Text('Medicação: ${widget.idosoData['nome']}'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.amber))
        : _medicacoes.isEmpty 
          ? const Center(child: Text('Nenhuma medicação registada.', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _medicacoes.length,
              itemBuilder: (context, index) {
                final med = _medicacoes[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.medication, color: Colors.white)),
                    title: Text(med['nome'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${med['quantidade']} - ${med['regularidade']}\nStock: ${med['stock_atual']}'),
                        if (med['observacoes'] != null && med['observacoes'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('Obs: ${med['observacoes']}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Colors.blueGrey)),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _addOrEditMed(med)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Eliminar'),
                              content: const Text('Deseja eliminar este medicamento?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Não')),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sim')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _supabase.from('medicacoes').delete().eq('id', med['id']);
                            _fetchMedicacoes();
                          }
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditMed(),
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

