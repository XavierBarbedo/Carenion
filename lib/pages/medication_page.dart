import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils.dart';

class MedicamentosPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const MedicamentosPage({super.key, required this.userData});

  @override
  State<MedicamentosPage> createState() => _MedicamentosPageState();
}

class _MedicamentosPageState extends State<MedicamentosPage>
    with SingleTickerProviderStateMixin {
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
      final familiasRes = await _supabase
          .from('familias')
          .select()
          .order('nome');
      final idososRes = await _supabase
          .from('idosos')
          .select('*, medicacoes(*)')
          .order('nome');

      setState(() {
        _stockFamilia = (familiasRes as List).map((f) {
          f['idosos'] = (idososRes as List)
              .where((i) => i['familia_id'] == f['id'])
              .toList();
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

      final medsRes = await _supabase
          .from('medicacoes')
          .select('*, idosos(*, familias(*))');

      if (medsRes is List && medsRes.isNotEmpty) {
        final tomasRes = await _supabase
            .from('medicacao_tomas')
            .select()
            .filter('medicacao_id', 'in', medsRes.map((m) => m['id']).toList())
            .gte('data', startOfWeek.toIso8601String().substring(0, 10))
            .lte(
              'data',
              startOfWeek
                  .add(const Duration(days: 6))
                  .toIso8601String()
                  .substring(0, 10),
            );

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
            final checkToma = (tomasRes as List).any(
              (t) => t['medicacao_id'] == med['id'] && t['data'] == dayStr,
            );

            projection.add({
              ...med,
              'familia_nome':
                  med['idosos']?['familias']?['nome'] ?? 'Sem Família',
              'familia_id': med['idosos']?['familias']?['id'],
              'idoso_nome': med['idosos']?['nome'] ?? 'Desconhecido',
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
      case 1:
        return 'Segunda';
      case 2:
        return 'Terça';
      case 3:
        return 'Quarta';
      case 4:
        return 'Quinta';
      case 5:
        return 'Sexta';
      case 6:
        return 'Sábado';
      case 7:
        return 'Domingo';
      default:
        return '';
    }
  }

  Future<void> _marcarTomado(dynamic med) async {
    try {
      final now = DateTime.now().toIso8601String().substring(0, 10);
      final medDate = med['data_toma'] ?? now;

      if (medDate != now) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Apenas pode alterar o estado do dia atual!',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final isUndo = med['tomada'] == true;

      // Calcular quantidade diária baseada na regularidade e quantidade (dose)
      // Regularidade: "X vezes ao dia"
      int frequency = 1;
      if (med['regularidade'] != null) {
        final regMatch = RegExp(
          r'(\d+)',
        ).firstMatch(med['regularidade'].toString());
        if (regMatch != null) {
          frequency = int.tryParse(regMatch.group(1)!) ?? 1;
        }
      }

      // Quantidade/Dose: "Y comprimidos"
      int dose = 1;
      if (med['quantidade'] != null) {
        final doseMatch = RegExp(
          r'(\d+)',
        ).firstMatch(med['quantidade'].toString());
        if (doseMatch != null) {
          dose = int.tryParse(doseMatch.group(1)!) ?? 1;
        }
      }

      final int amountToAdjust = frequency * dose;

      if (isUndo) {
        // 1. Remover a toma (Voltar atrás)
        await _supabase
            .from('medicacao_tomas')
            .delete()
            .eq('medicacao_id', med['id'])
            .eq('data', now);

        // 2. Recuperar stock
        await _supabase
            .from('medicacoes')
            .update({'stock_atual': (med['stock_atual'] ?? 0) + amountToAdjust})
            .eq('id', med['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Toma revertida e stock recuperado!',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } else {
        // 1. Verificar se existe stock suficiente
        final currentStock = med['stock_atual'] ?? 0;
        if (currentStock < amountToAdjust) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Stock insuficiente para marcar como tomado!',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // 2. Logar a toma
        await _supabase.from('medicacao_tomas').insert({
          'medicacao_id': med['id'],
          'data': now,
          'quantidade_tomada': amountToAdjust,
        });

        // 3. Atualizar stock (retirar equivalentes aos comprimidos por dia)
        await _supabase
            .from('medicacoes')
            .update({'stock_atual': currentStock - amountToAdjust})
            .eq('id', med['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Medicação marcada como tomada!',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao processar: $e')));
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
        children: [_buildTomasSemana(), _buildStockFamilia()],
      ),
    );
  }

  Widget _buildTomasSemana() {
    if (_isLoading)
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    if (_tomasSemana.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma medicação agendada para esta semana.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // 1. Agrupar por Família
    Map<String, List<dynamic>> groupedByFamily = {};
    for (var item in _tomasSemana) {
      final famName = item['familia_nome'] ?? 'Sem Família';
      groupedByFamily.putIfAbsent(famName, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: groupedByFamily.keys.map((famName) {
        final familyItems = groupedByFamily[famName]!;

        // 2. Agrupar itens da família por data
        Map<String, List<dynamic>> groupedByDate = {};
        for (var item in familyItems) {
          final key = '${item['day_label']} (${item['date_label']})';
          groupedByDate.putIfAbsent(key, () => []).add(item);
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.amber.withOpacity(0.5)),
          ),
          color: Colors.amber.withOpacity(0.05),
          child: ExpansionTile(
            initiallyExpanded: true,
            shape: const Border(), // Remove the borders on expansion
            leading: const Icon(Icons.family_restroom, color: Colors.amber),
            title: Text(
              famName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.amber,
              ),
            ),
            iconColor: Colors.amber,
            collapsedIconColor: Colors.amber,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              ...groupedByDate.keys.map((dateKey) {
                final items = groupedByDate[dateKey]!;
                final isToday = items.any((i) => i['is_today']);

                return ExpansionTile(
                  initiallyExpanded: isToday,
                  title: Text(
                    dateKey,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isToday ? Colors.amber[800] : Colors.blueGrey,
                    ),
                  ),
                  children: items.map((item) {
                    final idosoNome = item['idoso_nome'] ?? 'Desconhecido';
                    final isFuture = item['is_future'];

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: isFuture ? Colors.grey[50] : null,
                      child: ListTile(
                        leading: Icon(
                          Icons.medical_services,
                          color: item['tomada']
                              ? Colors.green
                              : (isFuture ? Colors.grey : Colors.amber),
                        ),
                        title: Text(
                          item['nome'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Para: $idosoNome\n${item['regularidade']}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.settings,
                                color: Colors.blueGrey,
                                size: 20,
                              ),
                              onPressed: () async {
                                final idosoRes = await _supabase
                                    .from('idosos')
                                    .select()
                                    .eq('id', item['idoso_id'])
                                    .single();
                                if (mounted) {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ManageMedicacoesPage(
                                        idosoData: idosoRes,
                                      ),
                                    ),
                                  );
                                  _fetchData();
                                }
                              },
                            ),
                            if (item['tomada'])
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 30,
                                ),
                                onPressed: () => _marcarTomado(item),
                              )
                            else if (isFuture)
                              const Icon(
                                Icons.schedule,
                                color: Colors.grey,
                                size: 30,
                              ) // Ícone de relógio para futuro
                            else
                              IconButton(
                                icon: const Icon(
                                  Icons.circle_outlined,
                                  color: Colors.grey,
                                  size: 30,
                                ),
                                onPressed: () => _marcarTomado(item),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
              const SizedBox(height: 8),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStockFamilia() {
    if (_isLoading)
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
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
            title: Text(
              familia['nome'] ?? 'Sem nome',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${idosos.length} idosos associados'),
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
                    final meds = idoso['medicacoes'] as List;
                    return ExpansionTile(
                      title: Text(idoso['nome'] ?? 'Sem nome'),
                      subtitle: Text('${meds.length} medicamentos'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.green,
                            ),
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ManageMedicacoesPage(idosoData: idoso),
                                ),
                              );
                              _fetchData();
                            },
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      children: meds.isEmpty
                          ? [
                              const ListTile(
                                title: Text(
                                  'Sem medicação registada',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ]
                          : meds
                                .map(
                                  (m) => ListTile(
                                    title: Text(m['nome']),
                                    subtitle: Text(
                                      'Regularidade: ${m['regularidade']}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: (m['stock_atual'] ?? 0) < 5
                                                ? Colors.red.withOpacity(0.1)
                                                : Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            'Stock: ${m['stock_atual'] ?? 0}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: (m['stock_atual'] ?? 0) < 5
                                                  ? Colors.red
                                                  : Colors.green,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                            size: 20,
                                          ),
                                          tooltip: 'Editar',
                                          onPressed: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ManageMedicacoesPage(
                                                      idosoData: idoso,
                                                    ),
                                              ),
                                            );
                                            _fetchData();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          tooltip: 'Eliminar',
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                  'Eliminar Medicação',
                                                ),
                                                content: Text(
                                                  'Tem a certeza que deseja eliminar ${m['nome']}?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: const Text(
                                                      'Cancelar',
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Eliminar',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              try {
                                                await _supabase
                                                    .from('medicacoes')
                                                    .delete()
                                                    .eq('id', m['id']);
                                                _fetchData();
                                              } catch (e) {
                                                if (mounted)
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Erro ao eliminar: $e',
                                                      ),
                                                    ),
                                                  );
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
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
      final res = await _supabase
          .from('medicacoes')
          .select()
          .eq('idoso_id', widget.idosoData['id']);
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

    final stockController = TextEditingController(
      text: med?['stock_atual']?.toString() ?? '30',
    );
    final obsController = TextEditingController(text: med?['observacoes']);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // Use StatefulBuilder for dropdown updates
        builder: (context, setDialogState) => AlertDialog(
          title: Text(med == null ? 'Nova Medicação' : 'Editar Medicação'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: med?['nome'] ?? ''),
                  optionsBuilder: (TextEditingValue textEditingValue) =>
                      _searchMedication(textEditingValue.text),
                  onSelected: (String selection) =>
                      nomeController.text = selection,
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        controller.addListener(
                          () => nomeController.text = controller.text,
                        );
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
                TextField(
                  controller: doseController,
                  decoration: const InputDecoration(
                    labelText: 'Dose (ex: 1 comprimido)',
                    prefixIcon: Icon(Icons.science),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedRegularidade,
                  decoration: const InputDecoration(
                    labelText: 'Regularidade',
                    prefixIcon: Icon(Icons.repeat),
                  ),
                  items: regularidadeOptions
                      .map(
                        (opt) => DropdownMenuItem(value: opt, child: Text(opt)),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedRegularidade = val),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: stockController,
                  decoration: const InputDecoration(
                    labelText: 'Stock Atual',
                    prefixIcon: Icon(Icons.inventory),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: obsController,
                  decoration: const InputDecoration(
                    labelText: 'Observações',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                  maxLines: 3,
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
                    await _supabase
                        .from('medicacoes')
                        .update(data)
                        .eq('id', med['id']);
                  }
                  if (mounted) Navigator.pop(context);
                  _fetchMedicacoes();
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Erro: $e')));
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
          ? const Center(
              child: Text(
                'Nenhuma medicação registada.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _medicacoes.length,
              itemBuilder: (context, index) {
                final med = _medicacoes[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.amber,
                      child: Icon(Icons.medication, color: Colors.white),
                    ),
                    title: Text(
                      med['nome'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${med['quantidade']} - ${med['regularidade']}\nStock: ${med['stock_atual']}',
                        ),
                        if (med['observacoes'] != null &&
                            med['observacoes'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Obs: ${med['observacoes']}',
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _addOrEditMed(med),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Eliminar'),
                                content: const Text(
                                  'Deseja eliminar este medicamento?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Não'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Sim'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _supabase
                                  .from('medicacoes')
                                  .delete()
                                  .eq('id', med['id']);
                              _fetchMedicacoes();
                            }
                          },
                        ),
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
