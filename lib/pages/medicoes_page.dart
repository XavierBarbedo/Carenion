import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../utils.dart';
import '../services/cache_service.dart';

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
  final Set<int> _expandedIdosos = {};

  @override
  void initState() {
    super.initState();
    final cacheKey = 'medicoes_${widget.userData['id']}';
    if (cacheService.has(cacheKey)) {
      final cached = cacheService.get(cacheKey) as Map<String, dynamic>;
      _familias = cached['familias'];
      _medicoesPorIdoso = Map<int, List<dynamic>>.from(cached['medicoesPorIdoso']);
      _isLoading = false;
    }
    _fetchData();
  }
  Future<void> _fetchData() async {
    final cacheKey = 'medicoes_${widget.userData['id']}';
    if (!cacheService.has(cacheKey)) {
      setState(() => _isLoading = true);
    }
    try {
      final userId = widget.userData['id'];

      // 1. Busca famílias do utilizador com idosos e medições aninhados
      final List<dynamic> familiasRes;
      if (widget.userData['tipo'] == 'cuidadora') {
        final fcResponse = await _supabase
            .from('familia_cuidadores')
            .select('familia_id')
            .eq('cuidadora_id', userId);
        final familiaIds = (fcResponse as List).map((fc) => fc['familia_id'] as int).toList();
        if (familiaIds.isNotEmpty) {
          familiasRes = await _supabase
              .from('familias')
              .select('*, idosos:idosos!fk_idoso_familia(*, medicoes(*))')
              .inFilter('id', familiaIds)
              .order('nome');
        } else {
          familiasRes = [];
        }
      } else {
        familiasRes = await _supabase
            .from('familias')
            .select('*, idosos:idosos!fk_idoso_familia(*, medicoes(*))')
            .eq('user_id', userId)
            .order('nome');
      }

      final familias = List<Map<String, dynamic>>.from(familiasRes);
      _medicoesPorIdoso = {};

      if (familias.isNotEmpty) {
        for (var f in familias) {
          final idosos = f['idosos'] as List? ?? [];
          for (var idoso in idosos) {
            final mList = List<Map<String, dynamic>>.from(idoso['medicoes'] ?? []);
            // Ordenar medições por data_medicao descrescente
            mList.sort((a, b) => (b['data_medicao'] ?? '').toString().compareTo((a['data_medicao'] ?? '').toString()));
            _medicoesPorIdoso[idoso['id']] = mList;
          }
        }

        cacheService.set(cacheKey, {
          'familias': familias,
          'medicoesPorIdoso': _medicoesPorIdoso,
        });
        if (mounted) {
          setState(() {
            _familias = familias;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _familias = [];
            _medicoesPorIdoso = {};
          });
        }
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'images/carenion_Icon-removebg-preview.png',
              height: 35,
            ),
            const SizedBox(width: 10),
            const Text(
              'Medições de Saúde',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _familias.isEmpty
              ? Center(
                  child: Text(
                    widget.userData['tipo'] == 'cuidadora'
                        ? 'Nenhuma família associada.'
                        : 'Nenhuma família registada.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _familias.length,
                  itemBuilder: (context, index) {
                    final familia = _familias[index];
                    final idosos = familia['idosos'] as List;
                    return Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                          initiallyExpanded: true,
                          leading: familia['foto_url'] != null && familia['foto_url'].toString().isNotEmpty
                              ? CircleAvatar(
                                  backgroundImage: getAvatarProvider(familia['foto_url']),
                                  backgroundColor: Colors.amber.withOpacity(0.2),
                                )
                              : CircleAvatar(
                                  backgroundColor: Colors.amber.withOpacity(0.2),
                                  child: const Icon(Icons.family_restroom, color: Colors.amber),
                                ),
                          title: Text(
                            familia['nome'] ?? 'Sem nome',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          children: idosos.isEmpty
                              ? [
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'Sem idosos/as registados/as.',
                                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ]
                              : idosos.map((idoso) => _buildIdosoExpansionTile(idoso)).toList(),
                        ),
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

  IconData _getCategoryIcon(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'tensão arterial':
        return Icons.monitor_heart;
      case 'diabetes':
        return Icons.water_drop;
      default:
        return Icons.analytics_outlined;
    }
  }

  Widget _buildIdosoExpansionTile(dynamic idoso) {
    final idosoId = idoso['id'] as int;
    final isExpanded = _expandedIdosos.contains(idosoId);
    final medicoes = _medicoesPorIdoso[idosoId] ?? [];
    
    // Agrupar por tipo
    Map<String, List<dynamic>> medicoesAgrupadas = {};
    for (var m in medicoes) {
      final tipo = m['tipo'] ?? 'Outra';
      if (medicoesAgrupadas[tipo] == null) {
        medicoesAgrupadas[tipo] = [];
      }
      medicoesAgrupadas[tipo]!.add(m);
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 0),
        child: Card(
          color: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _expandedIdosos.add(idosoId);
                } else {
                  _expandedIdosos.remove(idosoId);
                }
              });
            },
            leading: idoso['foto_url'] != null && idoso['foto_url'].toString().isNotEmpty
                ? CircleAvatar(
                    backgroundImage: getAvatarProvider(idoso['foto_url']),
                    backgroundColor: Colors.amber.withOpacity(0.2),
                  )
                : const CircleAvatar(
                    backgroundColor: Colors.amber,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
            title: Text(
              idoso['nome'] ?? 'Sem nome',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.add_circle, color: Colors.amber, size: 28),
                  onPressed: () => _addMedicao(idoso),
                  tooltip: 'Adicionar Medição',
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more, color: Colors.grey),
                ),
              ],
            ),
            children: [
              if (medicoesAgrupadas.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Nenhuma medição registada para este/a ${formatIdoso(idoso['sexo'], capitalize: false)}.',
                    style: const TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic),
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
      ),
    );
  }

  Widget _buildCategoryExpansionTile(String categoria, List<dynamic> medicoes) {
    final icon = _getCategoryIcon(categoria);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: Colors.amber.withOpacity(0.1),
          child: Icon(icon, size: 14, color: Colors.amber),
        ),
        title: Text(
          categoria,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 14),
        ),
        children: medicoes.map((m) {
          final date = DateTime.tryParse(m['data_medicao'] ?? '');
          final dateStr = date != null ? DateFormat('dd/MM HH:mm').format(date) : 'Data inválida';
          final unidade = _getUnidade(categoria);

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(
                unidade.isNotEmpty ? '${m['valor']} $unidade' : m['valor'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Text(
                '$dateStr${m['observacoes'] != null && m['observacoes'].toString().isNotEmpty ? ' - ${m['observacoes']}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: () {
                final isCuidadora = widget.userData['tipo'] == 'cuidadora';
                final canDelete = !isCuidadora || (m['criado_por'] == widget.userData['id']);
                if (!canDelete) return const SizedBox.shrink();
                return IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  onPressed: () => _confirmDeleteMedicao(m),
                );
              }(),
            ),
          );
        }).toList(),
      ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Nova Medição para ${idoso['nome']}',
            overflow: TextOverflow.ellipsis,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
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
                          // Usar o auth UUID como fonte fidedigna para a FK criado_por
                          final authUid = _supabase.auth.currentUser?.id ?? widget.userData['id'];
                          final insertData = {
                            'idoso_id': idoso['id'],
                            'tipo': tipoFinal,
                            'valor': valor,
                            'data_medicao': selectedDate.toIso8601String(),
                            'observacoes': obsController.text,
                            'criado_por': authUid,
                          };
                          final response = await _supabase.from('medicoes').insert(insertData).select().single();
                          final int medId = response['id'];

                          if (widget.userData['tipo'] == 'cuidadora') {
                            await logCuidadoraAction(
                              acao: 'criar',
                              entidade: 'medição',
                              entidadeId: medId,
                              familiaId: idoso['familia_id'],
                              detalhes: '$tipoFinal: $valor ${_getUnidade(tipoFinal)}',
                              cuidadoraId: widget.userData['id'],
                            );
                          }
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMedicao(dynamic medicao) async {
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
        if (widget.userData['tipo'] == 'cuidadora') {
          final idosoRes = await _supabase
              .from('idosos')
              .select('familia_id')
              .eq('id', medicao['idoso_id'])
              .single();

          await logCuidadoraAction(
            acao: 'eliminar',
            entidade: 'medição',
            entidadeId: medicao['id'],
            familiaId: idosoRes['familia_id'],
            detalhes: '${medicao['tipo']}: ${medicao['valor']}',
            cuidadoraId: widget.userData['id'],
          );
        }
        await _supabase.from('medicoes').delete().eq('id', medicao['id']);
        _fetchData(); // Recarregar tudo
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(translateSupabaseError(e))));
        }
      }
    }
  }
}
