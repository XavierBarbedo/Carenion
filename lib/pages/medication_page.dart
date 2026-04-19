import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils.dart';
import '../main.dart';
import '../services/notification_service.dart';

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
  List<dynamic> _medsSos = [];
  List<dynamic> _stockFamilia = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userId = widget.userData['id'];

      // 1. Busca apenas as famílias do utilizador
      debugPrint('[DEBUG] Medicação: Buscando famílias para userId: $userId');
      final familiasRes = await _supabase
          .from('familias')
          .select()
          .eq('user_id', userId)
          .order('nome');
      
      debugPrint('[DEBUG] Medicação: Encontradas ${familiasRes.length} famílias');
      
      final familias = List<Map<String, dynamic>>.from(familiasRes);

      if (familias.isNotEmpty) {
        final familiaIds = familias.map((f) => f['id']).toList();

        // 2. Busca idosos destas famílias com as suas medicações
        final idososRes = await _supabase
            .from('idosos')
            .select('*, medicacoes!fk_medicacao_idoso(*)')
            .inFilter('familia_id', familiaIds)
            .order('nome');

        final idosos = List<Map<String, dynamic>>.from(idososRes);

        // 2.1 Buscar stock centralizado da tabela stock_familia
        final stockFamiliaRes = await _supabase
            .from('stock_familia')
            .select()
            .inFilter('familia_id', familiaIds);
        final Map<String, int> centralStockMap = {};
        for (var s in stockFamiliaRes) {
          final key = '${s['familia_id']}_${s['nome_medicamento']}';
          centralStockMap[key] = s['stock_atual'] ?? 0;
        }

        // Enriquecer medicações de cada idoso com stock centralizado
        for (var idoso in idosos) {
          final meds = idoso['medicacoes'] as List? ?? [];
          final familiaId = idoso['familia_id'];
          idoso['medicacoes'] = meds.map((m) {
            final stockKey = '${familiaId}_${m['nome'].toString().toLowerCase()}';
            return {
              ...m,
              'stock_atual': centralStockMap[stockKey] ?? 0,
            };
          }).toList();
        }

        setState(() {
          _stockFamilia = familias.map((f) {
            f['idosos'] = idosos
                .where((i) => i['familia_id'] == f['id'])
                .toList();
            return f;
          }).toList();
        });
      } else {
        setState(() => _stockFamilia = []);
      }

      _fetchTomasSemana();
    } catch (e) {
      debugPrint('Erro ao carregar dados de medicação: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTomasSemana() async {
    try {
      final userId = widget.userData['id'];
      final now = DateTime.now();
      final todayStr = now.toIso8601String().substring(0, 10);
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

      // 1. Primeiro buscamos as famílias do utilizador
      final familiasUserRes = await _supabase
          .from('familias')
          .select('id, nome')
          .eq('user_id', userId);
      
      final familiasMap = {for (var f in familiasUserRes) f['id']: f['nome']};

      if (familiasMap.isEmpty) {
        setState(() => _tomasSemana = []);
        return;
      }

      // 2. Buscamos os idosos destas famílias
      final idososFiltradosRes = await _supabase
          .from('idosos')
          .select('id, nome, familia_id')
          .inFilter('familia_id', familiasMap.keys.toList());
      
      final idososMap = {for (var i in idososFiltradosRes) i['id']: i};

      if (idososMap.isEmpty) {
        setState(() => _tomasSemana = []);
        return;
      }

      // 3. Buscamos medicações apenas para esses idosos (SEM joins SQL para evitar ambiguidade)
      final medsRes = await _supabase
          .from('medicacoes')
          .select()
          .inFilter('idoso_id', idososMap.keys.toList());

      // 3.1 Buscar stock centralizado da tabela stock_familia
      final stockRes = await _supabase
          .from('stock_familia')
          .select()
          .inFilter('familia_id', familiasMap.keys.toList());
      // Mapa: 'familiaId_nomeMinusculo' -> stock_atual
      final Map<String, int> stockMap = {};
      for (var s in stockRes) {
        final key = '${s['familia_id']}_${s['nome_medicamento']}';
        stockMap[key] = s['stock_atual'] ?? 0;
      }

      if (medsRes is List && medsRes.isNotEmpty) {
        final regularMeds = medsRes.where((m) => m['tipo'] != 'sos').toList();
        final sosMeds = medsRes.where((m) => m['tipo'] == 'sos').map((m) {
          final idoso = idososMap[m['idoso_id']];
          final familiaId = idoso?['familia_id'];
          final familiaNome = familiaId != null ? familiasMap[familiaId] : 'Sem Família';
          final stockKey = '${familiaId}_${m['nome'].toString().toLowerCase()}';
          return {
            ...m,
            'familia_nome': familiaNome ?? 'Sem Família',
            'idoso_nome': idoso?['nome'] ?? 'Desconhecido',
            'stock_atual': stockMap[stockKey] ?? 0,
            'familia_id': familiaId,
          };
        }).toList();

        setState(() => _medsSos = sosMeds);

        if (regularMeds.isEmpty) {
          setState(() => _tomasSemana = []);
          return;
        }

        final tomasRes = await _supabase
            .from('medicacao_tomas')
            .select()
            .filter('medicacao_id', 'in', regularMeds.map((m) => m['id']).toList())
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

          for (var med in regularMeds) {
            final checkToma = (tomasRes as List).any(
              (t) => t['medicacao_id'] == med['id'] && t['data'] == dayStr,
            );

            // Mapeamento manual de dados relacionais
            final idoso = idososMap[med['idoso_id']];
            final familiaId = idoso?['familia_id'];
            final familiaNome = familiaId != null ? familiasMap[familiaId] : 'Sem Família';
            final stockKey = '${familiaId}_${med['nome'].toString().toLowerCase()}';

            projection.add({
              ...med,
              'familia_nome': familiaNome ?? 'Sem Família',
              'familia_id': familiaId,
              'idoso_nome': idoso?['nome'] ?? 'Desconhecido',
              'stock_atual': stockMap[stockKey] ?? 0,
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
        setState(() {
          _tomasSemana = [];
          _medsSos = [];
        });
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

        // 2. Recuperar stock na tabela centralizada
        final int recoveredStock = (med['stock_atual'] ?? 0) + amountToAdjust;
        final String medNomeLower = med['nome'].toString().toLowerCase();
        final int familiaId = med['familia_id'];
        await _supabase
            .from('stock_familia')
            .update({'stock_atual': recoveredStock})
            .eq('familia_id', familiaId)
            .eq('nome_medicamento', medNomeLower);

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

        // 3. Atualizar stock na tabela centralizada
        final int newStock = currentStock - amountToAdjust;
        final String medNomeLower = med['nome'].toString().toLowerCase();
        final int familiaId = med['familia_id'];
        await _supabase
            .from('stock_familia')
            .update({'stock_atual': newStock})
            .eq('familia_id', familiaId)
            .eq('nome_medicamento', medNomeLower);

        if (newStock < settingsService.lowStockThreshold) {
          notificationService.showNotification(
            id: med['id'] + 9000000, 
            title: 'Stock Baixo: ${med['nome']}',
            body: 'Resta apenas $newStock unidades para o idoso ${med['idoso_nome']}.',
          );
        }

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

  Future<void> _marcarTomadoSos(dynamic med) async {
    final quantityController = TextEditingController(text: '1');
    final amountToAdjust = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Toma de Medicação SOS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Irá registar a toma de ${med['nome']} para ${med['idoso_nome']}.'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantidade Tomada',
                prefixIcon: Icon(Icons.science),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(quantityController.text);
              if (val != null && val > 0) {
                Navigator.pop(context, val);
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (amountToAdjust == null || amountToAdjust <= 0) return;

    try {
      final now = DateTime.now().toIso8601String().substring(0, 10);
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

      await _supabase.from('medicacao_tomas').insert({
        'medicacao_id': med['id'],
        'data': now,
        'quantidade_tomada': amountToAdjust,
      });

      final int newStock = currentStock - amountToAdjust;
      final String medNomeLower = med['nome'].toString().toLowerCase();
      final int familiaId = med['familia_id'];
      await _supabase
          .from('stock_familia')
          .update({'stock_atual': newStock})
          .eq('familia_id', familiaId)
          .eq('nome_medicamento', medNomeLower);

      if (newStock < settingsService.lowStockThreshold) {
        notificationService.showNotification(
          id: med['id'] + 9000000,
          title: 'Stock Baixo: ${med['nome']}',
          body: 'Resta apenas $newStock unidades para o idoso ${med['idoso_nome']}.',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Toma SOS registada com sucesso!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
          ),
        );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: 'Atualizar Dados',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Medicação SOS'),
            Tab(text: 'Medicação diária'),
            Tab(text: 'Stock por Família'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMedSOSPannel(), _buildTomasSemana(), _buildStockFamilia()],
      ),
    );
  }

  Widget _buildMedSOSPannel() {
    if (_isLoading)
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    if (_medsSos.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma medicação SOS registada.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    Map<String, List<dynamic>> groupedByFamily = {};
    for (var item in _medsSos) {
      final famName = item['familia_nome'] ?? 'Sem Família';
      groupedByFamily.putIfAbsent(famName, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: groupedByFamily.keys.map((famName) {
        final items = groupedByFamily[famName]!;

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
            leading: const Icon(Icons.family_restroom, color: Colors.amber),
            title: Text(
              famName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.amber,
              ),
            ),
            children: items.map((item) {
              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  title: Text(
                    item['nome'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Para: ${item['idoso_nome']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('Instruções: ${item['instrucoes_sos'] ?? 'Sem instruções'}'),
                    ],
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _marcarTomadoSos(item),
                    child: const Text('Tomar'),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
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
                        isThreeLine: true,
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Para: $idosoNome', style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text('Regularidade: ${item['regularidade']}'),
                            Text('Dose: ${item['quantidade']}'),
                          ],
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    }
    if (_stockFamilia.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.family_restroom, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nenhuma família encontrada.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            Text(
              'Crie uma família na aba "Idosos".',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }
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
                                            color: (m['stock_atual'] ?? 0) <
                                                    settingsService
                                                        .lowStockThreshold
                                                ? Colors.red.withOpacity(0.1)
                                                : Colors.green.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            'Stock: ${m['stock_atual'] ?? 0}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: (m['stock_atual'] ?? 0) <
                                                      settingsService
                                                          .lowStockThreshold
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

      // Buscar stock centralizado da família
      final int familiaId = widget.idosoData['familia_id'];
      final stockRes = await _supabase
          .from('stock_familia')
          .select()
          .eq('familia_id', familiaId);
      final Map<String, int> stockMap = {};
      for (var s in stockRes) {
        stockMap[s['nome_medicamento']] = s['stock_atual'] ?? 0;
      }

      // Enriquecer cada medicamento com o stock centralizado
      final enriched = res.map((m) {
        final stockKey = m['nome'].toString().toLowerCase();
        return {
          ...m,
          'stock_atual': stockMap[stockKey] ?? 0,
        };
      }).toList();

      setState(() => _medicacoes = enriched);
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
    final List<String> tipoOptions = ['normal', 'sos'];
    String _selectedTipo = med?['tipo'] ?? 'normal';

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
    final instrucoesSosController = TextEditingController(text: med?['instrucoes_sos']);

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
                DropdownButtonFormField<String>(
                  value: _selectedTipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Medicação',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: tipoOptions
                      .map((opt) => DropdownMenuItem(
                            value: opt,
                            child: Text(opt == 'normal' ? 'Regular' : 'SOS'),
                          ))
                      .toList(),
                  onChanged: (val) => setDialogState(() => _selectedTipo = val!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: doseController,
                  decoration: const InputDecoration(
                    labelText: 'Dose (ex: 1 comprimido)',
                    prefixIcon: Icon(Icons.science),
                  ),
                ),
                if (_selectedTipo == 'normal') ...[
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
                ],
                if (_selectedTipo == 'sos') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: instrucoesSosController,
                    decoration: const InputDecoration(
                      labelText: 'Instruções SOS',
                      prefixIcon: Icon(Icons.warning),
                    ),
                    maxLines: 2,
                  ),
                ],
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
                
                // Validação de regularidade para tipo normal
                if (_selectedTipo == 'normal' && selectedRegularidade == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor seleccione a regularidade'))
                  );
                  return;
                }

                final stockValue = int.tryParse(stockController.text) ?? 0;
                final data = {
                  'idoso_id': widget.idosoData['id'],
                  'nome': nomeController.text,
                  'quantidade': doseController.text,
                  'regularidade': _selectedTipo == 'normal' ? selectedRegularidade : 'em caso de emergência',
                  'observacoes': obsController.text,
                  'tipo': _selectedTipo,
                  'instrucoes_sos': _selectedTipo == 'sos' ? instrucoesSosController.text : null,
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

                  // Atualizar stock na tabela centralizada (upsert)
                  final int updatedStock = stockValue;
                  final String medNomeLower = nomeController.text.toLowerCase();
                  final int familiaId = widget.idosoData['familia_id'];

                  await _supabase.from('stock_familia').upsert({
                    'familia_id': familiaId,
                    'nome_medicamento': medNomeLower,
                    'stock_atual': updatedStock,
                  }, onConflict: 'familia_id,nome_medicamento');

                  if (updatedStock < settingsService.lowStockThreshold) {
                    notificationService.showNotification(
                      id: (med?['id'] ?? 9999) + 9000000,
                      title: 'Stock Baixo: ${data['nome']}',
                      body: 'Resta apenas $updatedStock unidades.',
                    );
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
                          'Para: ${widget.idosoData['nome']}\nRegularidade: ${med['regularidade']}\nDose: ${med['quantidade']}\nStock: ${med['stock_atual']}',
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
