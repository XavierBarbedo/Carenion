import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../utils.dart';

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
  Map<int, List<dynamic>> _medicoesPorIdoso = {};

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
        final idosoIds = idosos.map((i) => i['id']).toList();

        // 3. Busca todas as medições destes idosos
        if (idosoIds.isNotEmpty) {
          final medicoesRes = await _supabase
              .from('medicoes')
              .select()
              .inFilter('idoso_id', idosoIds)
              .order('data_medicao', ascending: false);
          
          final medicoes = medicoesRes as List;
          _medicoesPorIdoso = {};
          for (var m in medicoes) {
            final idosoId = m['idoso_id'];
            if (_medicoesPorIdoso[idosoId] == null) {
              _medicoesPorIdoso[idosoId] = [];
            }
            _medicoesPorIdoso[idosoId]!.add(m);
          }
        }

        setState(() {
          _familias = familias.map((f) {
            f['idosos'] = idosos
                .where((i) => i['familia_id'] == f['id'])
                .toList();
            return f;
          }).toList();
        });
      } else {
        setState(() {
          _familias = [];
          _medicoesPorIdoso = {};
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: Image.asset('images/carenion_Icon-removebg-preview.png'),
        ),
        title: const Text(
          'Medições de Saúde',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2D2600)
            : const Color(0xFFFFFBE6),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.amber),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        leading: const Icon(Icons.family_restroom, color: Colors.amber),
                        title: Text(
                          familia['nome'] ?? 'Sem nome',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        children: idosos.isEmpty
                            ? [
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'Sem idosos registados.',
                                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ]
                            : idosos.map((idoso) => _buildIdosoExpansionTile(idoso)).toList(),
                      ),
                    );
                  },
                ),
    );
  }

  String _getUnidade(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'tensão arterial':
        return 'mmHg';
      case 'diabetes':
        return 'mg/dL';
      default:
        return '';
    }
  }

  Widget _buildIdosoExpansionTile(dynamic idoso) {
    final medicoes = _medicoesPorIdoso[idoso['id']] ?? [];
    
    // Agrupar por tipo
    Map<String, List<dynamic>> medicoesAgrupadas = {};
    for (var m in medicoes) {
      final tipo = m['tipo'] ?? 'Outra';
      if (medicoesAgrupadas[tipo] == null) {
        medicoesAgrupadas[tipo] = [];
      }
      medicoesAgrupadas[tipo]!.add(m);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Card(
        color: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey[900] 
            : Colors.grey[50],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        child: ExpansionTile(
          leading: const Icon(Icons.person, color: Colors.blueGrey),
          title: Text(
            idoso['nome'],
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.amber),
            onPressed: () => _addMedicao(idoso),
            tooltip: 'Adicionar Medição',
          ),
          children: [
            if (medicoesAgrupadas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Nenhuma medição registada para este idoso.',
                  style: TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              )
            else
              ...medicoesAgrupadas.entries.map((entry) {
                return _buildCategoryExpansionTile(entry.key, entry.value);
              }).toList(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryExpansionTile(String categoria, List<dynamic> medicoes) {
    return ExpansionTile(
      dense: true,
      title: Text(
        categoria,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
      ),
      children: medicoes.map((m) {
        final date = DateTime.tryParse(m['data_medicao'] ?? '');
        final dateStr = date != null ? DateFormat('dd/MM HH:mm').format(date) : 'Data inválida';
        final unidade = _getUnidade(categoria);

        return ListTile(
          dense: true,
          leading: const Icon(Icons.monitor_heart, size: 18, color: Colors.amber),
          title: Text(
            unidade.isNotEmpty ? '${m['valor']} $unidade' : m['valor'],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('$dateStr${m['observacoes'] != null && m['observacoes'].toString().isNotEmpty ? ' - ${m['observacoes']}' : ''}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
            onPressed: () => _confirmDeleteMedicao(m['id']),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _addMedicao(dynamic idoso) async {
    String selectedTipo = 'Tensão Arterial';
    final List<String> tipos = ['Tensão Arterial', 'Diabetes', 'Outra'];
    
    final tipoOutraController = TextEditingController();
    final valorController = TextEditingController();
    final obsController = TextEditingController();
    
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Nova Medição para ${idoso['nome']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedTipo,
                  decoration: InputDecoration(
                    label: buildRequiredLabel('Tipo de Medição'),
                    prefixIcon: const Icon(Icons.monitor_heart),
                  ),
                  items: tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setDialogState(() => selectedTipo = val!),
                ),
                if (selectedTipo == 'Outra') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: tipoOutraController,
                    decoration: InputDecoration(
                      label: buildRequiredLabel('Qual é a medição?'),
                      prefixIcon: const Icon(Icons.edit),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: valorController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    label: buildRequiredLabel('Valor da Medição'),
                    prefixIcon: const Icon(Icons.numbers),
                    suffixText: _getUnidade(selectedTipo),
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
                      locale: const Locale('pt', 'PT'),
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
                final tipoFinal = selectedTipo == 'Outra' ? tipoOutraController.text.trim() : selectedTipo;

                if (valor.isEmpty || tipoFinal.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor preencha o tipo e o valor.')),
                  );
                  return;
                }

                try {
                  await _supabase.from('medicoes').insert({
                    'idoso_id': idoso['id'],
                    'tipo': tipoFinal,
                    'valor': valor,
                    'data_medicao': selectedDate.toIso8601String(),
                    'observacoes': obsController.text,
                  });
                  if (mounted) Navigator.pop(context);
                  _fetchData(); // Recarregar tudo
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(translateSupabaseError(e))),
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

  Future<void> _confirmDeleteMedicao(dynamic id) async {
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
        _fetchData(); // Recarregar tudo
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateSupabaseError(e))));
        }
      }
    }
  }
}
