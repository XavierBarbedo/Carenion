import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'medication_page.dart';

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
        final idosoIds = userIdososResponse
            .map((ui) => ui['idoso_id'])
            .toList();

        final idososResponse = await supabase
            .from('idosos')
            .select()
            .inFilter('id', idosoIds);

        final idosos = List<Map<String, dynamic>>.from(idososResponse);

        // Mapear idosos para as famílias
        for (var familia in familias) {
          familia['idosos'] = idosos
              .where((i) => i['familia_id'] == familia['id'])
              .toList();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e')));
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
                  const Icon(
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma família registada',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.amber.withOpacity(0.2),
                      child: const Icon(
                        Icons.family_restroom,
                        color: Colors.amber,
                      ),
                    ),
                    title: Text(
                      familia['nome'] ?? 'Sem nome',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${listIdosos.length} idosos associados'),
                    children: [
                      if (listIdosos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Nenhum idoso nesta família',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ...listIdosos
                          .map(
                            (idoso) => ListTile(
                              leading: const Icon(
                                Icons.person,
                                color: Colors.amber,
                              ),
                              title: Text(idoso['nome'] ?? 'Sem nome'),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                              ),
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => IdosoDetailsPage(
                                      idosoData: idoso,
                                      userId: widget.userData['id'],
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  _fetchIdosos();
                                }
                              },
                            ),
                          )
                          .toList(),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RegisterIdosoPage(
                                  userId: widget.userData['id'],
                                  initialFamiliaId: familia['id'],
                                ),
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
              const SnackBar(
                content: Text('Por favor, registe primeiro uma família'),
              ),
            );
            return;
          }
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  RegisterIdosoPage(userId: widget.userData['id']),
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
  const RegisterIdosoPage({
    super.key,
    required this.userId,
    this.initialFamiliaId,
  });

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
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 70),
      ), // Idoso
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Selecione a data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (picked != null) {
      setState(() {
        _dataNascController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
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
      final idosoResponse = await supabase
          .from('idosos')
          .insert({
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
          })
          .select()
          .single();

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
          errorMessage =
              'Erro de permissão ou utilizador inválido (FK violation)';
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
              _buildTextField(
                _nomeController,
                'Nome Completo',
                Icons.person_outline,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: IgnorePointer(
                  child: _buildTextField(
                    _dataNascController,
                    'Data de Nascimento',
                    Icons.calendar_today_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedFamiliaId,
                decoration: InputDecoration(
                  labelText: 'Família',
                  prefixIcon: const Icon(Icons.family_restroom_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _familias
                    .map(
                      (f) => DropdownMenuItem<int>(
                        value: f['id'],
                        child: Text(f['nome'] ?? 'Sem nome'),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedFamiliaId = val),
                validator: (value) =>
                    value == null ? 'Seleccione uma família' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _sexo,
                decoration: InputDecoration(
                  labelText: 'Sexo',
                  prefixIcon: const Icon(Icons.wc_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Masculino')),
                  DropdownMenuItem(value: 'F', child: Text('Feminino')),
                  DropdownMenuItem(value: 'O', child: Text('Outro')),
                ],
                onChanged: (val) => setState(() => _sexo = val!),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _nifController,
                'NIF',
                Icons.badge_outlined,
                hintText: 'Ex: 123456789',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _telefoneController,
                'Telefone',
                Icons.phone_outlined,
                hintText: 'Ex: 912345678',
              ),
              const SizedBox(height: 16),
              _buildTextField(_moradaController, 'Morada', Icons.home_outlined),
              const SizedBox(height: 16),
              _buildTextField(
                _patologiasController,
                'Patologias/Doenças',
                Icons.medical_information_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _obsController,
                'Observações',
                Icons.note_add_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _registerIdoso,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Guardar Registo',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    String? hintText,
  }) {
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
      validator: (value) =>
          value == null || value.isEmpty ? 'Campo obrigatório' : null,
    );
  }
}

class IdosoDetailsPage extends StatelessWidget {
  final Map<String, dynamic> idosoData;
  final String userId;
  const IdosoDetailsPage({
    super.key,
    required this.idosoData,
    required this.userId,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Registo'),
        content: Text(
          'Tem a certeza que deseja eliminar o registo de ${idosoData['nome']}?',
        ),
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

    if (confirmed == true) {
      try {
        final supabase = Supabase.instance.client;

        // Deletar relação primeiro (ou deixar o cascade do banco fazer)
        await supabase
            .from('user_idoso')
            .delete()
            .eq('idoso_id', idosoData['id']);
        // Deletar o idoso
        await supabase.from('idosos').delete().eq('id', idosoData['id']);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registo eliminado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao eliminar: $e'),
            backgroundColor: Colors.red,
          ),
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
            _buildDetailItem(
              Icons.calendar_today_outlined,
              'Data de Nascimento',
              idosoData['data_nascimento'],
            ),
            _buildDetailItem(
              Icons.wc_outlined,
              'Sexo',
              idosoData['sexo'] == 'M'
                  ? 'Masculino'
                  : idosoData['sexo'] == 'F'
                  ? 'Feminino'
                  : 'Outro',
            ),
            _buildDetailItem(Icons.badge_outlined, 'NIF', idosoData['nif']),
            _buildDetailItem(
              Icons.phone_outlined,
              'Telefone',
              idosoData['telefone'],
            ),
            _buildDetailItem(
              Icons.home_outlined,
              'Morada',
              idosoData['morada'],
            ),
            _buildDetailItem(
              Icons.medical_information_outlined,
              'Patologias',
              idosoData['patologias'],
            ),
            _buildDetailItem(
              Icons.note_add_outlined,
              'Observações',
              idosoData['observacoes'],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ManageMedicacoesPage(idosoData: idosoData),
                    ),
                  );
                },
                icon: const Icon(Icons.medication),
                label: const Text(
                  'Gerir Medicação',
                  style: TextStyle(fontSize: 18),
                ),
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
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value?.toString() ?? 'Não preenchido',
                  style: const TextStyle(fontSize: 18),
                ),
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
    _dataNascController = TextEditingController(
      text: widget.idosoData['data_nascimento'],
    );
    _nifController = TextEditingController(text: widget.idosoData['nif']);
    _telefoneController = TextEditingController(
      text: widget.idosoData['telefone'],
    );
    _moradaController = TextEditingController(text: widget.idosoData['morada']);
    _patologiasController = TextEditingController(
      text: widget.idosoData['patologias'],
    );
    _obsController = TextEditingController(
      text: widget.idosoData['observacoes'],
    );
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
        _dataNascController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _updateIdoso() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('idosos')
          .update({
            'nome': _nomeController.text,
            'data_nascimento': _dataNascController.text,
            'sexo': _sexo,
            'nif': _nifController.text,
            'telefone': _telefoneController.text,
            'morada': _moradaController.text,
            'patologias': _patologiasController.text,
            'observacoes': _obsController.text,
            'familia_id': _selectedFamiliaId,
          })
          .eq('id', widget.idosoData['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados atualizados com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
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
              _buildTextField(
                _nomeController,
                'Nome Completo',
                Icons.person_outline,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: IgnorePointer(
                  child: _buildTextField(
                    _dataNascController,
                    'Data de Nascimento',
                    Icons.calendar_today_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedFamiliaId,
                decoration: InputDecoration(
                  labelText: 'Família',
                  prefixIcon: const Icon(Icons.family_restroom_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _familias
                    .map(
                      (f) => DropdownMenuItem<int>(
                        value: f['id'],
                        child: Text(f['nome'] ?? 'Sem nome'),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedFamiliaId = val),
                validator: (value) =>
                    value == null ? 'Seleccione uma família' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _sexo,
                decoration: InputDecoration(
                  labelText: 'Sexo',
                  prefixIcon: const Icon(Icons.wc_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'M', child: Text('Masculino')),
                  DropdownMenuItem(value: 'F', child: Text('Feminino')),
                  DropdownMenuItem(value: 'O', child: Text('Outro')),
                ],
                onChanged: (val) => setState(() => _sexo = val!),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _nifController,
                'NIF',
                Icons.badge_outlined,
                hintText: 'Ex: 123456789',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _telefoneController,
                'Telefone',
                Icons.phone_outlined,
                hintText: 'Ex: 912345678',
              ),
              const SizedBox(height: 16),
              _buildTextField(_moradaController, 'Morada', Icons.home_outlined),
              const SizedBox(height: 16),
              _buildTextField(
                _patologiasController,
                'Patologias/Doenças',
                Icons.medical_information_outlined,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _obsController,
                'Observações',
                Icons.note_add_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _updateIdoso,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Salvar Alterações',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    String? hintText,
  }) {
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
      validator: (value) =>
          value == null || value.isEmpty ? 'Campo obrigatório' : null,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar famílias: $e')),
        );
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await _supabase.from('familias').insert({
                    'nome': controller.text,
                  });
                  _hasChanges = true;
                  if (mounted) Navigator.pop(context);
                  _fetchFamilias();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao adicionar: $e')),
                    );
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await _supabase
                      .from('familias')
                      .update({'nome': controller.text})
                      .eq('id', familia['id']);
                  _hasChanges = true;
                  if (mounted) Navigator.pop(context);
                  _fetchFamilias();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro ao editar: $e')),
                    );
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
        content: Text(
          'Tem a certeza que deseja eliminar a família ${familia['nome']}?',
        ),
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

    if (confirmed == true) {
      try {
        final idososResponse = await _supabase
            .from('idosos')
            .select()
            .eq('familia_id', familia['id']);
        if (idososResponse.isNotEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Não é possível eliminar uma família com idosos associados.',
                ),
              ),
            );
          }
          return;
        }

        await _supabase.from('familias').delete().eq('id', familia['id']);
        _hasChanges = true;
        _fetchFamilias();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro ao eliminar: $e')));
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
                    leading: const Icon(
                      Icons.family_restroom,
                      color: Colors.amber,
                    ),
                    title: Text(familia['nome'] ?? 'Sem nome'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                          ),
                          onPressed: () => _editFamilia(familia),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
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
