import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'medication_page.dart';
import '../utils.dart';

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

      // 1. Busca apenas as famílias do utilizador
      debugPrint('[DEBUG] IdososPage: Buscando famílias para userId: ${widget.userData['id']}');
      final familiasResponse = await supabase
          .from('familias')
          .select()
          .eq('user_id', widget.userData['id'])
          .order('nome');
      
      debugPrint('[DEBUG] IdososPage: Encontradas ${familiasResponse.length} famílias');

      final familias = List<Map<String, dynamic>>.from(familiasResponse);

      if (familias.isNotEmpty) {
        final familiaIds = familias.map((f) => f['id']).toList();

        // 2. Busca todos os idosos que pertencem a estas famílias
        final idososResponse = await supabase
            .from('idosos')
            .select()
            .inFilter('familia_id', familiaIds);

        final idosos = List<Map<String, dynamic>>.from(idososResponse);

        // 3. Mapear idosos para as suas respetivas famílias
        for (var familia in familias) {
          familia['idosos'] = idosos
              .where((i) => i['familia_id'] == familia['id'])
              .toList();
        }
      } else {
        // Se não houver famílias, não há idosos
      }

      setState(() {
        _familias = familias;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(translateSupabaseError(e))));
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'images/carenion_Icon-removebg-preview.png',
              height: 35,
            ),
            const SizedBox(width: 10),
            const Text(
              'Famílias e Idosos/as',
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
            icon: const Icon(Icons.family_restroom),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FamiliasPage(userData: widget.userData),
                ),
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
                        MaterialPageRoute(
                          builder: (context) => 
                              FamiliasPage(userData: widget.userData),
                        ),
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
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: familia['foto_url'] != null && familia['foto_url'].toString().isNotEmpty
                        ? CircleAvatar(
                            backgroundImage: getAvatarProvider(familia['foto_url']),
                            backgroundColor: Colors.amber.withOpacity(0.2),
                          )
                        : CircleAvatar(
                            backgroundColor: Colors.amber.withOpacity(0.2),
                            child: const Icon(
                              Icons.family_restroom,
                              color: Colors.amber,
                            ),
                          ),
                    title: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        familia['nome'] ?? 'Sem nome',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    subtitle: Text('${listIdosos.length} associados'),
                    children: [
                      if (listIdosos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Ninguém registado nesta família',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ...listIdosos
                          .map(
                            (idoso) => ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              leading: idoso['foto_url'] != null && idoso['foto_url'].toString().isNotEmpty
                                  ? CircleAvatar(
                                      backgroundImage: getAvatarProvider(idoso['foto_url']),
                                      backgroundColor: Colors.amber.withOpacity(0.2),
                                    )
                                  : const CircleAvatar(
                                      backgroundColor: Colors.amber,
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      ),
                                    ),
                              title: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(idoso['nome'] ?? 'Sem nome'),
                              ),
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
                          label: const Text('Adicionar Idoso/a a esta Família'),
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

  final _snsController = TextEditingController();
  final _ccController = TextEditingController();
  final _seguroQualController = TextEditingController();
  final _seguroNumController = TextEditingController();
  bool _temSeguroSaude = false;

  String _sexo = 'M';
  int? _selectedFamiliaId;
  List<dynamic> _familias = [];
  bool _isLoading = false;

  Uint8List? _fotoBytes;
  XFile? _fotoFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _fotoFile = pickedFile;
        _fotoBytes = bytes;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedFamiliaId = widget.initialFamiliaId;
    _fetchFamilias();
  }

  Future<void> _fetchFamilias() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('familias')
          .select()
          .eq('user_id', widget.userId)
          .order('nome');
      setState(() {
        _familias = response;
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
      locale: const Locale('pt', 'PT'),
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

      String? fotoUrl;
      if (_fotoFile != null && _fotoBytes != null) {
        fotoUrl = 'data:image/jpeg;base64,${base64Encode(_fotoBytes!)}';
      }

      // 1. Inserir na tabela 'idosos'
      final idosoResponse = await supabase
          .from('idosos')
          .insert({
            'nome': _nomeController.text,
            'data_nascimento': _dataNascController.text,
            'sexo': _sexo,
            'nif': _nifController.text,
            'sns_numero': _snsController.text,
            'cc_bi': _ccController.text,
            'seguro_saude': _temSeguroSaude ? _seguroQualController.text : null,
            'seguro_numero': _temSeguroSaude ? _seguroNumController.text : null,
            'telefone': _telefoneController.text,
            'morada': _moradaController.text,
            'patologias': _patologiasController.text,
            'observacoes': _obsController.text,
            'familia_id': _selectedFamiliaId,
            'foto_url': fotoUrl,
            'criado_em': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final idosoId = idosoResponse['id'];
      print('DEBUG: Idoso criado com ID: $idosoId');

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(translateSupabaseError(e)),
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'images/carenion_Icon-removebg-preview.png',
              height: 35,
            ),
            const SizedBox(width: 10),
            const Text(
              'Registar Idoso/a',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.amber.withOpacity(0.2),
                        backgroundImage: _fotoBytes != null ? MemoryImage(_fotoBytes!) : null,
                        child: _fotoBytes == null
                            ? const Icon(Icons.person, size: 50, color: Colors.amber)
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
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                  label: buildRequiredLabel('Família'),
                  prefixIcon: const Icon(Icons.family_restroom_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _familias
                    .map(
                      (f) => DropdownMenuItem<int>(
                        value: f['id'],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            f['foto_url'] != null && f['foto_url'].toString().isNotEmpty
                                ? CircleAvatar(
                                    radius: 12,
                                    backgroundImage: getAvatarProvider(f['foto_url']),
                                    backgroundColor: Colors.amber.withOpacity(0.2),
                                  )
                                : CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.amber.withOpacity(0.2),
                                    child: const Icon(Icons.family_restroom, size: 12, color: Colors.amber),
                                  ),
                            const SizedBox(width: 8),
                            Text(f['nome'] ?? 'Sem nome'),
                          ],
                        ),
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
                  label: buildRequiredLabel('Sexo'),
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
                isRequired: true,
                hintText: 'Ex: 123456789',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _snsController,
                'Número de Utente do SNS',
                Icons.medical_services_outlined,
                isRequired: false,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _ccController,
                'CC/BI',
                Icons.credit_card_outlined,
                isRequired: false,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Tem Seguro de Saúde?'),
                value: _temSeguroSaude,
                activeColor: Colors.amber,
                onChanged: (bool value) {
                  setState(() {
                    _temSeguroSaude = value;
                  });
                },
              ),
              if (_temSeguroSaude) ...[
                const SizedBox(height: 8),
                _buildTextField(
                  _seguroQualController,
                  'Qual o Seguro?',
                  Icons.health_and_safety_outlined,
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _seguroNumController,
                  'Número do Seguro',
                  Icons.numbers,
                  isRequired: false,
                ),
              ],
              const SizedBox(height: 16),
              _buildTextField(
                _telefoneController,
                'Telefone',
                Icons.phone_outlined,
                isRequired: false,
                hintText: 'Ex: 912345678',
              ),
              const SizedBox(height: 16),
              _buildTextField(_moradaController, 'Morada', Icons.home_outlined,
                  isRequired: false,
                  hintText: 'Ex: Rua das Flores, n.º 10, Lisboa'),
              const SizedBox(height: 16),
              _buildTextField(
                _patologiasController,
                'Patologias/Doenças',
                Icons.medical_information_outlined,
                maxLines: 2,
                isRequired: false,
                hintText: 'Ex: Diabetes, Hipertensão, Alzheimer',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _obsController,
                'Observações',
                Icons.note_add_outlined,
                maxLines: 3,
                isRequired: false,
                hintText: 'Ex: Alérgico a penicilina, prefere ler à tarde',
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
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        label: isRequired ? buildRequiredLabel(label) : Text(label),
        hintText: hintText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (!isRequired) return null;
        return (value == null || value.isEmpty) ? 'Campo obrigatório' : null;
      },
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

        // Deletar o idoso - O cascade do banco tratará de medicações e eventos
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
            content: Text(translateSupabaseError(e)),
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'images/carenion_Icon-removebg-preview.png',
              height: 35,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  idosoData['nome'] ?? 'Detalhes',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditIdosoPage(
                    idosoData: idosoData,
                    userId: userId,
                  ),
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
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.amber.withOpacity(0.2),
                backgroundImage: idosoData['foto_url'] != null && idosoData['foto_url'].toString().isNotEmpty
                    ? getAvatarProvider(idosoData['foto_url'])
                    : null,
                child: idosoData['foto_url'] == null || idosoData['foto_url'].toString().isEmpty
                    ? const Icon(Icons.person, size: 60, color: Colors.amber)
                    : null,
              ),
            ),
            const SizedBox(height: 24),
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
            _buildDetailItem(Icons.medical_services_outlined, 'SNS', idosoData['sns_numero']),
            _buildDetailItem(Icons.credit_card_outlined, 'CC/BI', idosoData['cc_bi']),
            if (idosoData['seguro_saude'] != null && idosoData['seguro_saude'].toString().isNotEmpty) ...[
              _buildDetailItem(Icons.health_and_safety_outlined, 'Seguro de Saúde', idosoData['seguro_saude']),
              _buildDetailItem(Icons.numbers, 'Nº Seguro', idosoData['seguro_numero']),
            ],
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
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Icon(icon, color: Colors.amber, size: 22),
            ),
          ),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    value?.toString() ?? 'Não preenchido',
                    style: const TextStyle(fontSize: 18),
                  ),
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
  final String userId;
  const EditIdosoPage({
    super.key,
    required this.idosoData,
    required this.userId,
  });

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
  late TextEditingController _snsController;
  late TextEditingController _ccController;
  late TextEditingController _seguroQualController;
  late TextEditingController _seguroNumController;
  late bool _temSeguroSaude;

  late String _sexo;
  int? _selectedFamiliaId;
  List<dynamic> _familias = [];
  bool _isLoading = false;

  Uint8List? _fotoBytes;
  String? _currentFotoUrl;
  XFile? _fotoFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _fotoFile = pickedFile;
        _fotoBytes = bytes;
      });
    }
  }

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
    _snsController = TextEditingController(text: widget.idosoData['sns_numero']);
    _ccController = TextEditingController(text: widget.idosoData['cc_bi']);
    _seguroQualController = TextEditingController(text: widget.idosoData['seguro_saude']);
    _seguroNumController = TextEditingController(text: widget.idosoData['seguro_numero']);
    _temSeguroSaude = widget.idosoData['seguro_saude'] != null && widget.idosoData['seguro_saude'].toString().isNotEmpty;

    _currentFotoUrl = widget.idosoData['foto_url'];
    _sexo = widget.idosoData['sexo'] ?? 'M';
    _selectedFamiliaId = widget.idosoData['familia_id'];
    _fetchFamilias();
  }

  Future<void> _fetchFamilias() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = widget.userId;
      
      debugPrint('[DEBUG] IdososPage: Buscando famílias para userId: $userId');
      
      final response = await supabase
          .from('familias')
          .select()
          .eq('user_id', userId)
          .order('nome');
      
      debugPrint('[DEBUG] IdososPage: Encontradas ${response.length} famílias');
      
      setState(() {
        _familias = response;
      });
    } catch (e) {
      debugPrint('[DEBUG] IdososPage: Erro ao carregar famílias: $e');
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

      String? fotoUrl = _currentFotoUrl;
      if (_fotoFile != null && _fotoBytes != null) {
        fotoUrl = 'data:image/jpeg;base64,${base64Encode(_fotoBytes!)}';
      }

      await supabase
          .from('idosos')
          .update({
            'nome': _nomeController.text,
            'data_nascimento': _dataNascController.text,
            'sexo': _sexo,
            'nif': _nifController.text,
            'sns_numero': _snsController.text,
            'cc_bi': _ccController.text,
            'seguro_saude': _temSeguroSaude ? _seguroQualController.text : null,
            'seguro_numero': _temSeguroSaude ? _seguroNumController.text : null,
            'telefone': _telefoneController.text,
            'morada': _moradaController.text,
            'patologias': _patologiasController.text,
            'observacoes': _obsController.text,
            'familia_id': _selectedFamiliaId,
            'foto_url': fotoUrl,
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
            content: Text(translateSupabaseError(e)),
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'images/carenion_Icon-removebg-preview.png',
              height: 35,
            ),
            const SizedBox(width: 10),
            const Text(
              'Editar Idoso/a',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.amber.withOpacity(0.2),
                        backgroundImage: _fotoBytes != null 
                            ? MemoryImage(_fotoBytes!) 
                            : getAvatarProvider(_currentFotoUrl),
                        child: _fotoBytes == null && (_currentFotoUrl == null || _currentFotoUrl!.isEmpty)
                            ? const Icon(Icons.person, size: 50, color: Colors.amber)
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
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                  label: buildRequiredLabel('Família'),
                  prefixIcon: const Icon(Icons.family_restroom_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _familias
                    .map(
                      (f) => DropdownMenuItem<int>(
                        value: f['id'],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            f['foto_url'] != null && f['foto_url'].toString().isNotEmpty
                                ? CircleAvatar(
                                    radius: 12,
                                    backgroundImage: getAvatarProvider(f['foto_url']),
                                    backgroundColor: Colors.amber.withOpacity(0.2),
                                  )
                                : CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.amber.withOpacity(0.2),
                                    child: const Icon(Icons.family_restroom, size: 12, color: Colors.amber),
                                  ),
                            const SizedBox(width: 8),
                            Text(f['nome'] ?? 'Sem nome'),
                          ],
                        ),
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
                  label: buildRequiredLabel('Sexo'),
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
                isRequired: true,
                hintText: 'Ex: 123456789',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _snsController,
                'Número de Utente do SNS',
                Icons.medical_services_outlined,
                isRequired: false,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _ccController,
                'CC/BI',
                Icons.credit_card_outlined,
                isRequired: false,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Tem Seguro de Saúde?'),
                value: _temSeguroSaude,
                activeColor: Colors.amber,
                onChanged: (bool value) {
                  setState(() {
                    _temSeguroSaude = value;
                  });
                },
              ),
              if (_temSeguroSaude) ...[
                const SizedBox(height: 8),
                _buildTextField(
                  _seguroQualController,
                  'Qual o Seguro?',
                  Icons.health_and_safety_outlined,
                  isRequired: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _seguroNumController,
                  'Número do Seguro',
                  Icons.numbers,
                  isRequired: false,
                ),
              ],
              const SizedBox(height: 16),
              _buildTextField(
                _telefoneController,
                'Telefone',
                Icons.phone_outlined,
                isRequired: false,
                hintText: 'Ex: 912345678',
              ),
              const SizedBox(height: 16),
              _buildTextField(_moradaController, 'Morada', Icons.home_outlined,
                  isRequired: false,
                  hintText: 'Ex: Rua das Flores, n.º 10, Lisboa'),
              const SizedBox(height: 16),
              _buildTextField(
                _patologiasController,
                'Patologias/Doenças',
                Icons.medical_information_outlined,
                maxLines: 2,
                isRequired: false,
                hintText: 'Ex: Diabetes, Hipertensão, Alzheimer',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                _obsController,
                'Observações',
                Icons.note_add_outlined,
                maxLines: 3,
                isRequired: false,
                hintText: 'Ex: Alérgico a penicilina, prefere ler à tarde',
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
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        label: isRequired ? buildRequiredLabel(label) : Text(label),
        hintText: hintText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        if (!isRequired) return null;
        return (value == null || value.isEmpty) ? 'Campo obrigatório' : null;
      },
    );
  }
}

class FamiliasPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const FamiliasPage({super.key, required this.userData});

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
      final response = await _supabase
          .from('familias')
          .select()
          .eq('user_id', widget.userData['id'])
          .order('nome');
      setState(() => _familias = response);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translateSupabaseError(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addFamilia() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const FamiliaFormDialog(),
    );

    if (result != null && result['nome'].isNotEmpty) {
      try {
        await _supabase.from('familias').insert({
          'nome': result['nome'],
          'foto_url': result['foto_url'],
          'user_id': _supabase.auth.currentUser!.id,
        });
        _hasChanges = true;
        _fetchFamilias();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(translateSupabaseError(e))),
          );
        }
      }
    }
  }

  Future<void> _editFamilia(Map<String, dynamic> familia) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => FamiliaFormDialog(familia: familia),
    );

    if (result != null && result['nome'].isNotEmpty) {
      try {
        await _supabase
            .from('familias')
            .update({
              'nome': result['nome'],
              'foto_url': result['foto_url'],
            })
            .eq('id', familia['id']);
        _hasChanges = true;
        _fetchFamilias();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(translateSupabaseError(e))),
          );
        }
      }
    }
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
          ).showSnackBar(SnackBar(content: Text(translateSupabaseError(e))));
        }
      }
    }
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
              'Gerir Famílias',
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
                    leading: familia['foto_url'] != null && familia['foto_url'].toString().isNotEmpty
                        ? CircleAvatar(
                            backgroundImage: getAvatarProvider(familia['foto_url']),
                            backgroundColor: Colors.amber.withOpacity(0.2),
                          )
                        : CircleAvatar(
                            backgroundColor: Colors.amber.withOpacity(0.2),
                            child: const Icon(
                              Icons.family_restroom,
                              color: Colors.amber,
                            ),
                          ),
                    title: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(familia['nome'] ?? 'Sem nome'),
                    ),
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

class FamiliaFormDialog extends StatefulWidget {
  final Map<String, dynamic>? familia;
  const FamiliaFormDialog({super.key, this.familia});

  @override
  State<FamiliaFormDialog> createState() => _FamiliaFormDialogState();
}

class _FamiliaFormDialogState extends State<FamiliaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeController;
  Uint8List? _fotoBytes;
  String? _currentFotoUrl;
  XFile? _fotoFile;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(
      text: widget.familia != null ? widget.familia!['nome'] : '',
    );
    _currentFotoUrl = widget.familia != null ? widget.familia!['foto_url'] : null;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _fotoFile = pickedFile;
        _fotoBytes = bytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.familia == null ? 'Nova Família' : 'Editar Família'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.amber.withOpacity(0.2),
                      backgroundImage: _fotoBytes != null
                          ? MemoryImage(_fotoBytes!)
                          : getAvatarProvider(_currentFotoUrl),
                      child: _fotoBytes == null &&
                              (_currentFotoUrl == null || _currentFotoUrl!.isEmpty)
                          ? const Icon(Icons.family_restroom, size: 40, color: Colors.amber)
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
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeController,
                decoration: InputDecoration(
                  label: buildRequiredLabel('Nome da Família'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Campo obrigatório';
                  }
                  return null;
                },
                autofocus: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _isLoading = true);
                  
                  String? fotoUrl = _currentFotoUrl;
                  if (_fotoFile != null && _fotoBytes != null) {
                    fotoUrl = 'data:image/jpeg;base64,${base64Encode(_fotoBytes!)}';
                  }
                  
                  Navigator.pop(context, {
                    'nome': _nomeController.text.trim(),
                    'foto_url': fotoUrl,
                  });
                },
          child: _isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
