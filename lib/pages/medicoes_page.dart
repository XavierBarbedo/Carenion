import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MedicoesPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const MedicoesPage({super.key, required this.userData});

  @override
  State<MedicoesPage> createState() => _MedicoesPageState();
}

class _MedicoesPageState extends State<MedicoesPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _familias = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userId = widget.userData['id'];

      // 1. Busca famílias do utilizador
      final familiasRes = await _supabase
          .from('familias')
          .select()
          .eq('user_id', userId)
          .order('nome');

      final familias = List<Map<String, dynamic>>.from(familiasRes);

      if (familias.isNotEmpty) {
        final familiaIds = familias.map((f) => f['id']).toList();

        // 2. Busca idosos destas famílias
        final idososRes = await _supabase
            .from('idosos')
            .select()
            .inFilter('familia_id', familiaIds)
            .order('nome');

        final idosos = List<Map<String, dynamic>>.from(idososRes);

        setState(() {
          _familias = familias.map((f) {
            f['idosos'] = idosos
                .where((i) => i['familia_id'] == f['id'])
                .toList();
            return f;
          }).toList();
        });
      } else {
        setState(() => _familias = []);
      }
    } catch (e) {
      debugPrint('Erro ao carregar idosos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medições de Saúde'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _familias.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma família registada.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _familias.length,
                  itemBuilder: (context, index) {
                    final familia = _familias[index];
                    final idosos = familia['idosos'] as List;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        leading: const Icon(Icons.family_restroom, color: Colors.amber),
                        title: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            familia['nome'] ?? 'Sem nome',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        children: idosos.isEmpty
                            ? [
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Sem idosos registados.',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ]
                            : idosos.map((idoso) {
                                return ListTile(
                                  leading: const Icon(Icons.person, color: Colors.blueGrey),
                                  title: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Text(idoso['nome']),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ManageMedicoesPage(idosoData: idoso),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                      ),
                    );
                  },
                ),
    );
  }
}

class ManageMedicoesPage extends StatefulWidget {
  final Map<String, dynamic> idosoData;
  const ManageMedicoesPage({super.key, required this.idosoData});

  @override
  State<ManageMedicoesPage> createState() => _ManageMedicoesPageState();
}

class _ManageMedicoesPageState extends State<ManageMedicoesPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _medicoes = [];

  @override
  void initState() {
    super.initState();
    _fetchMedicoes();
  }

  Future<void> _fetchMedicoes() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase
          .from('medicoes')
          .select()
          .eq('idoso_id', widget.idosoData['id'])
          .order('data_medicao', ascending: false);
      setState(() => _medicoes = res);
    } catch (e) {
      debugPrint('Erro ao carregar medições: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addMedicao() async {
    String _selectedTipo = 'Tensão Arterial';
    final List<String> tipos = ['Tensão Arterial', 'Diabetes', 'Outra'];
    
    final tipoOutraController = TextEditingController();
    final valorController = TextEditingController();
    final obsController = TextEditingController();
    
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova Medição'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedTipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Medição',
                    prefixIcon: Icon(Icons.monitor_heart),
                  ),
                  items: tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setDialogState(() => _selectedTipo = val!),
                ),
                if (_selectedTipo == 'Outra') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: tipoOutraController,
                    decoration: const InputDecoration(
                      labelText: 'Qual é a medição?',
                      prefixIcon: Icon(Icons.edit),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: valorController,
                  decoration: const InputDecoration(
                    labelText: 'Valor da Medição',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text('Data: ${DateFormat('dd/MM/yyyy HH:mm').format(selectedDate)}'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (t != null) {
                        setDialogState(() {
                          selectedDate = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: obsController,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                  maxLines: 2,
                ),
              ],
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
              onPressed: () async {
                final valor = valorController.text.trim();
                final tipoFinal = _selectedTipo == 'Outra' ? tipoOutraController.text.trim() : _selectedTipo;

                if (valor.isEmpty || tipoFinal.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor preencha o tipo e o valor.')),
                  );
                  return;
                }

                try {
                  await _supabase.from('medicoes').insert({
                    'idoso_id': widget.idosoData['id'],
                    'tipo': tipoFinal,
                    'valor': valor,
                    'data_medicao': selectedDate.toIso8601String(),
                    'observacoes': obsController.text,
                  });
                  if (mounted) Navigator.pop(context);
                  _fetchMedicoes();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erro: $e')),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMedicao(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('Tem a certeza que deseja eliminar esta medição?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _supabase.from('medicoes').delete().eq('id', id);
        _fetchMedicoes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text('Medições: ${widget.idosoData['nome']}'),
        ),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _medicoes.isEmpty
              ? const Center(
                  child: Text(
                    'Nenhuma medição registada.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _medicoes.length,
                  itemBuilder: (context, index) {
                    final m = _medicoes[index];
                    final date = DateTime.tryParse(m['data_medicao'] ?? '');
                    final dateStr = date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : 'Data inválida';

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.withOpacity(0.2),
                          child: const Icon(Icons.favorite, color: Colors.amber),
                        ),
                        title: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text('${m['tipo']}: ${m['valor']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        subtitle: Text('$dateStr\n${m['observacoes'] ?? ''}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () => _deleteMedicao(m['id']),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMedicao,
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
