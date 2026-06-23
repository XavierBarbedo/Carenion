import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../services/notification_service.dart';
import '../utils.dart';
import '../services/cache_service.dart';

class AgendaPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AgendaPage({super.key, required this.userData});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  final _supabase = Supabase.instance.client;
  static const _platform = MethodChannel('com.example.carenion/maps');

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    final cacheKey = 'agenda_${widget.userData['id']}';
    if (cacheService.has(cacheKey)) {
      _events = Map<DateTime, List<dynamic>>.from(cacheService.get(cacheKey));
      _isLoading = false;
    }
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    final cacheKey = 'agenda_${widget.userData['id']}';
    if (!cacheService.has(cacheKey)) {
      setState(() => _isLoading = true);
    }
    try {
      final userId = widget.userData['id'];

      // 1. Busca as famílias e os seus idosos aninhados numa única chamada de rede
      debugPrint('[DEBUG] Agenda: Buscando famílias para userId: $userId');
      final List<dynamic> familiasUserRes;
      if (widget.userData['tipo'] == 'cuidadora') {
        final fcResponse = await _supabase
            .from('familia_cuidadores')
            .select('familia_id')
            .eq('cuidadora_id', userId);
        final familiaIds = (fcResponse as List).map((fc) => fc['familia_id'] as int).toList();
        if (familiaIds.isNotEmpty) {
          familiasUserRes = await _supabase
              .from('familias')
              .select('id, nome, idosos:idosos!fk_idoso_familia(id, nome, familia_id, foto_url)')
              .inFilter('id', familiaIds);
        } else {
          familiasUserRes = [];
        }
      } else {
        familiasUserRes = await _supabase
            .from('familias')
            .select('id, nome, idosos:idosos!fk_idoso_familia(id, nome, familia_id, foto_url)')
            .eq('user_id', userId);
      }
      
      final familiasMap = {for (var f in familiasUserRes) f['id']: f['nome']};

      if (familiasMap.isEmpty) {
        setState(() {
          _events = {};
        });
        return;
      }

      // Extrair todos os idosos aninhados
      final List<dynamic> idososFiltradosRes = [];
      for (var f in familiasUserRes) {
        if (f['idosos'] != null) {
          idososFiltradosRes.addAll(f['idosos']);
        }
      }
      
      final idososMap = {for (var i in idososFiltradosRes) i['id']: i};

      if (idososMap.isEmpty) {
        setState(() {
          _events = {};
        });
        return;
      }

      // 3. Buscamos eventos apenas para esses idosos (SEM joins SQL para evitar ambiguidade)
      final response = await _supabase
          .from('eventos')
          .select('*, users(nome, tipo, foto_url)')
          .inFilter('idoso_id', idososMap.keys.toList())
          .order('data_inicio');

      final Map<DateTime, List<dynamic>> newEvents = {};

      for (var event in response as List) {
        final startDate = DateTime.parse(event['data_inicio']);
        final day = DateTime(startDate.year, startDate.month, startDate.day);

        // Mapeamento manual de dados relacionais
        final idoso = idososMap[event['idoso_id']];
        final familiaId = idoso?['familia_id'];
        final familiaNome = familiaId != null ? familiasMap[familiaId] : 'Sem Família';

        if (newEvents[day] == null) {
          newEvents[day] = [];
        }
        newEvents[day]!.add({
          ...event,
          'idoso_nome': idoso?['nome'] ?? 'Desconhecido',
          'familia_nome': familiaNome ?? 'Sem Família',
          'familia_id': familiaId,
          'foto_url': idoso?['foto_url'],
        });
      }

      cacheService.set(cacheKey, newEvents);
      if (mounted) {
        setState(() {
          _events = newEvents;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar eventos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
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
              'Agenda de Cuidados',
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchEvents),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            eventLoader: _getEventsForDay,
            locale: settingsService.calendarLanguage == 'pt' ? 'pt_PT' : 'en_US',
            availableCalendarFormats: settingsService.calendarLanguage == 'pt'
                ? const {
                    CalendarFormat.month: 'Mês',
                    CalendarFormat.twoWeeks: '2 Semanas',
                    CalendarFormat.week: 'Semana',
                  }
                : const {
                    CalendarFormat.month: 'Month',
                    CalendarFormat.twoWeeks: '2 Weeks',
                    CalendarFormat.week: 'Week',
                  },
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.amberAccent,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.amber,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              dowBuilder: (context, day) {
                if (settingsService.calendarLanguage == 'pt') {
                  final ptDays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
                  final text = ptDays[day.weekday - 1];
                  return Center(
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  );
                }
                return null;
              },
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  )
                : _buildEventList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
                MaterialPageRoute(
                  builder: (context) => AddEventoPage(
                    selectedDate: _selectedDay ?? DateTime.now(),
                    userData: widget.userData,
                  ),
                ),
          );
          if (result == true) _fetchEvents();
        },
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay ?? _focusedDay);
    if (events.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum evento para este dia.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final startTime = DateTime.parse(event['data_inicio']);
        final timeStr = DateFormat('HH:mm').format(startTime);

        final now = DateTime.now();
        final diff = startTime.difference(now);
        final isUpcoming = diff.inMinutes > 0 &&
            diff.inMinutes <= settingsService.eventNotificationTime;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isUpcoming
                ? const BorderSide(color: Colors.redAccent, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showEventDetails(context, event, timeStr),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getEventTypeColor(event['tipo']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  timeStr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getEventTypeColor(event['tipo']),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        event['titulo'] ?? 'Sem Título',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (isUpcoming)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_active,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Próximo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      'Para: ${event['idoso_nome']} (${event['familia_nome']})',
                    ),
                  ),
                  Text('Tipo: ${event['tipo'] ?? 'Outro'}'),
                  if (event['users'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: getAvatarProvider(event['users']['foto_url']),
                            backgroundColor: Colors.amber.withOpacity(0.2),
                            child: (event['users']['foto_url'] == null || event['users']['foto_url'].toString().isEmpty)
                                ? const Icon(Icons.person, size: 10, color: Colors.amber)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event['users']['tipo'] == 'cuidadora'
                                  ? 'Criado por Cuidador(a): ${event['users']['nome'] ?? 'Desconhecido'}'
                                  : 'Criado por: ${event['users']['nome'] ?? 'Desconhecido'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              trailing: () {
                final isCuidadora = widget.userData['tipo'] == 'cuidadora';
                final canModify = !isCuidadora || (event['criado_por'] == widget.userData['id']);
                if (!canModify) return const SizedBox.shrink();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                                builder: (context) => AddEventoPage(
                                  selectedDate: startTime,
                                  event: event,
                                  userData: widget.userData,
                                ),
                          ),
                        );
                        if (result == true) {
                          _fetchEvents();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _confirmDelete(event),
                    ),
                  ],
                );
              }(),
            isThreeLine: true,
          ),
        ),
      );
    },
  );
}

  void _showEventDetails(BuildContext context, dynamic event, String timeStr) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final loc = event['localizacao']?.toString().trim() ?? '';
        final desc = event['descricao']?.toString().trim() ?? '';

        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    event['titulo'] ?? 'Sem Título',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${event['tipo']} • $timeStr',
                  style: TextStyle(
                    fontSize: 16,
                    color: _getEventTypeColor(event['tipo']),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(height: 30),
                 _detailRow(
                  Icons.person,
                  'Idoso/a',
                  '${event['idoso_nome']} (${event['familia_nome']})',
                  fotoUrl: event['foto_url'],
                ),
                if (event['users'] != null)
                  _detailRow(
                    Icons.assignment_ind,
                    'Criado por',
                    '${event['users']['nome'] ?? 'Utilizador'} (${event['users']['tipo'] == 'cuidadora' ? 'Cuidador(a)' : 'Administrador'})',
                    fotoUrl: event['users']['foto_url'],
                  ),
                if (loc.isNotEmpty)
                  _detailRow(Icons.location_on, 'Localização', loc),
                if (desc.isNotEmpty)
                  _detailRow(Icons.description, 'Descrição', desc),
                const SizedBox(height: 20),
                if (loc.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.map),
                      label: const Text('Ver Direções no Mapa Padrão'),
                      onPressed: () async {
                        try {
                          await _platform.invokeMethod('openMap', {
                            'address': loc,
                          });
                        } catch (e) {
                          // Fallback UI or ignore
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _detailRow(IconData icon, String title, String value, {String? fotoUrl}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: (fotoUrl != null && fotoUrl.isNotEmpty)
                  ? CircleAvatar(radius: 12, backgroundImage: getAvatarProvider(fotoUrl))
                  : Icon(icon, size: 20, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(value, style: const TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getEventTypeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'consulta':
        return Colors.blue;
      case 'exame':
        return Colors.purple;
      case 'higiene':
        return Colors.teal;
      case 'refeição':
        return Colors.orange;
      case 'tratamento':
        return Colors.green;
      case 'medicação':
        return Colors.pink;
      default:
        return Colors.amber;
    }
  }

  Future<void> _confirmDelete(dynamic event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Evento'),
        content: const Text('Tem a certeza que deseja eliminar este evento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
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
          await logCuidadoraAction(
            acao: 'eliminar',
            entidade: 'evento',
            entidadeId: event['id'],
            familiaId: event['familia_id'],
            detalhes: event['titulo'] ?? 'Sem Título',
            cuidadoraId: widget.userData['id'],
          );
        }
        await _supabase.from('eventos').delete().eq('id', event['id']);
        await notificationService.cancelNotification(event['id']);
        _fetchEvents();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(translateSupabaseError(e))));
      }
    }
  }
}

class AddEventoPage extends StatefulWidget {
  final DateTime selectedDate;
  final Map<dynamic, dynamic>? event;
  final Map<String, dynamic> userData;

  const AddEventoPage({
    super.key,
    required this.selectedDate,
    required this.userData,
    this.event,
  });

  @override
  State<AddEventoPage> createState() => _AddEventoPageState();
}

class _AddEventoPageState extends State<AddEventoPage> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _tituloController = TextEditingController();
  final _descController = TextEditingController();
  final _localController = TextEditingController();
  final _outroController = TextEditingController();

  String _selectedTipo = 'Consulta';
  int? _selectedFamiliaId;
  int? _selectedIdosoId;
  TimeOfDay _selectedTime = TimeOfDay.now();

  List<dynamic> _familias = [];
  List<dynamic> _idosos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _tituloController.text = widget.event!['titulo'] ?? '';
      _descController.text = widget.event!['descricao'] ?? '';
      _localController.text = widget.event!['localizacao'] ?? '';
      final eventTipo = widget.event!['tipo'] ?? 'Outro';
      final predefinedTypes = ['Consulta', 'Exame', 'Higiene', 'Refeição', 'Tratamento', 'Medicação'];
      if (predefinedTypes.contains(eventTipo)) {
        _selectedTipo = eventTipo;
      } else {
        _selectedTipo = 'Outro';
        _outroController.text = eventTipo;
      }
      if (widget.event!['data_inicio'] != null) {
        final dt = DateTime.parse(widget.event!['data_inicio']);
        _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
      _selectedIdosoId = widget.event!['idoso_id'];
    }
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final userId = widget.userData['id'];

      final List<dynamic> famRes;
      if (widget.userData['tipo'] == 'cuidadora') {
        final fcResponse = await _supabase
            .from('familia_cuidadores')
            .select('familia_id')
            .eq('cuidadora_id', userId);
        final familiaIds = (fcResponse as List).map((fc) => fc['familia_id'] as int).toList();
        if (familiaIds.isNotEmpty) {
          famRes = await _supabase
              .from('familias')
              .select()
              .inFilter('id', familiaIds)
              .order('nome');
        } else {
          famRes = [];
        }
      } else {
        famRes = await _supabase
            .from('familias')
            .select()
            .eq('user_id', userId)
            .order('nome');
      }
      setState(() {
        _familias = famRes;
      });
      if (widget.event != null && widget.event!['familia_id'] != null) {
        _selectedFamiliaId = widget.event!['familia_id'];
        _fetchIdosos(_selectedFamiliaId!);
      }
    } catch (e) {
      debugPrint('Erro ao carregar famílias: $e');
    }
  }

  Future<void> _fetchIdosos(int familiaId) async {
    try {
      final idosoRes = await _supabase
          .from('idosos')
          .select()
          .eq('familia_id', familiaId)
          .order('nome');
      setState(() {
        _idosos = idosoRes;
        if (widget.event == null || !_idosos.any((i) => i['id'] == _selectedIdosoId)) {
            _selectedIdosoId = null;
        }
      });
    } catch (e) {
      debugPrint('Erro ao carregar idosos: $e');
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
            Text(
              widget.event != null ? 'Editar Evento' : 'Novo Evento',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
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
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data: ${DateFormat('dd/MM/yyyy').format(widget.selectedDate)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  label: buildRequiredLabel('Família'),
                  prefixIcon: const Icon(Icons.family_restroom),
                ),
                value: _selectedFamiliaId,
                items: _familias
                    .map(
                      (f) => DropdownMenuItem<int>(
                        value: f['id'],
                        child: Text(f['nome']),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedFamiliaId = val);
                    _fetchIdosos(val);
                  }
                },
                validator: (v) => v == null ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  label: buildRequiredLabel('Idoso/a'),
                  prefixIcon: const Icon(Icons.person),
                ),
                value: _selectedIdosoId,
                items: _idosos
                    .map(
                      (i) => DropdownMenuItem<int>(
                        value: i['id'],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            i['foto_url'] != null && i['foto_url'].toString().isNotEmpty
                                ? CircleAvatar(radius: 12, backgroundImage: getAvatarProvider(i['foto_url']))
                                : const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 12)),
                            const SizedBox(width: 8),
                            Text(i['nome']),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedIdosoId = val),
                validator: (v) => v == null ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _tituloController,
                decoration: InputDecoration(
                  label: buildRequiredLabel('Título do Evento'),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  label: buildRequiredLabel('Tipo'),
                  prefixIcon: const Icon(Icons.category),
                ),
                value: _selectedTipo,
                items: ['Consulta', 'Exame', 'Higiene', 'Refeição', 'Tratamento', 'Medicação', 'Outro']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedTipo = val ?? 'Outro'),
              ),
              if (_selectedTipo == 'Outro') ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _outroController,
                  decoration: InputDecoration(
                    label: buildRequiredLabel('Qual? (Especifique o tipo)'),
                    prefixIcon: const Icon(Icons.edit_note),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Por favor, especifique o tipo' : null,
                ),
              ],
              const SizedBox(height: 16),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('Hora'),
                subtitle: Text(_selectedTime.format(context)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _selectedTime,
                  );
                  if (time != null) setState(() => _selectedTime = time);
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _localController,
                      decoration: const InputDecoration(
                        labelText: 'Localização',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.map, color: Colors.blueAccent),
                    tooltip: 'Escolher no Mapa',
                    onPressed: () async {
                      final coords = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MapPickerPage(),
                        ),
                      );
                      if (coords != null && coords.isNotEmpty) {
                        setState(() {
                          _localController.text = coords;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Descrição / Notas',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _isLoading ? null : _saveEvento,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Guardar Evento',
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

  Future<void> _saveEvento() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);
  try {
    final startDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final eventData = {
      'idoso_id': _selectedIdosoId,
      'titulo': _tituloController.text,
      'descricao': _descController.text,
      'tipo': _selectedTipo == 'Outro' ? _outroController.text.trim() : _selectedTipo,
      'data_inicio': startDateTime.toIso8601String(),
      'localizacao': _localController.text,
      if (widget.event == null) 'criado_por': widget.userData['id'],
    };

    if (widget.event != null) {
        await _supabase.from('eventos').update(eventData).eq('id', widget.event!['id']);
        _scheduleEventNotification(widget.event!['id'], startDateTime);
        
        if (widget.userData['tipo'] == 'cuidadora') {
          await logCuidadoraAction(
            acao: 'editar',
            entidade: 'evento',
            entidadeId: widget.event!['id'],
            familiaId: _selectedFamiliaId!,
            detalhes: _tituloController.text,
            cuidadoraId: widget.userData['id'],
          );
        }
    } else {
        eventData['criado_em'] = DateTime.now().toIso8601String();
        final response = await _supabase.from('eventos').insert(eventData).select().single();
        final int eventId = response['id'];
        _scheduleEventNotification(eventId, startDateTime);
        
        if (widget.userData['tipo'] == 'cuidadora') {
          await logCuidadoraAction(
            acao: 'criar',
            entidade: 'evento',
            entidadeId: eventId,
            familiaId: _selectedFamiliaId!,
            detalhes: _tituloController.text,
            cuidadoraId: widget.userData['id'],
          );
        }
    }

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.event != null ? 'Evento atualizado com sucesso!' : 'Evento marcado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(translateSupabaseError(e))));
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _scheduleEventNotification(int eventId, DateTime startDateTime) {
    final int minutesBefore = settingsService.eventNotificationTime;
    final DateTime scheduledTime = startDateTime.subtract(Duration(minutes: minutesBefore));

    notificationService.scheduleNotification(
      id: eventId,
      title: 'Lembrete: ${_tituloController.text}',
      body: 'Evento agendado para as ${DateFormat('HH:mm').format(startDateTime)}',
      scheduledDate: scheduledTime,
    );
  }
}

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({Key? key}) : super(key: key);

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  LatLng _center = const LatLng(38.7223, -9.1393); // Lisbon center default
  String _currentAddress = 'A carregar localização...';
  bool _ready = false;
  bool _isSearching = false;
  bool _isReverseGeocoding = false;
  bool _isMoving = false;
  List<dynamic> _searchResults = [];

  late AnimationController _pinAnimationController;
  late Animation<double> _pinJumpAnimation;

  @override
  void initState() {
    super.initState();
    _pinAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pinJumpAnimation = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(parent: _pinAnimationController, curve: Curves.easeOut),
    );
    _reverseGeocode(_center);
  }

  @override
  void dispose() {
    _pinAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() {
      _isReverseGeocoding = true;
    });

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'carenion/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'];
        if (address != null) {
          final road = address['road'] ?? address['pedestrian'] ?? address['suburb'] ?? '';
          final city = address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'] ?? '';
          
          if (road.isNotEmpty && city.isNotEmpty) {
            setState(() {
              _currentAddress = '$road, $city';
            });
          } else if (data['display_name'] != null) {
            // Fallback to display_name but try to keep it short
            final parts = data['display_name'].toString().split(',');
            if (parts.length > 2) {
              setState(() {
                _currentAddress = '${parts[0].trim()}, ${parts[1].trim()}';
              });
            } else {
              setState(() {
                _currentAddress = data['display_name'];
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      setState(() {
        _currentAddress = 'Localização desconhecida';
      });
    } finally {
      setState(() {
        _isReverseGeocoding = false;
      });
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5',
      );
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'carenion/1.0', // Nominatim requires a user agent
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _searchResults = data;
        });
      } else {
        debugPrint('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _moveToLocation(double lat, double lon) {
    setState(() {
      _center = LatLng(lat, lon);
      _searchResults = []; // Hide results after selection
      _searchController.clear();
      FocusScope.of(context).unfocus(); // Close keyboard
    });
    _mapController.move(_center, 15.0);
    _reverseGeocode(_center);
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
              'Selecionar no Mapa',
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
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13.0,
              onMapReady: () {
                setState(() => _ready = true);
              },
              onPositionChanged: (MapCamera camera, bool hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _center = camera.center;
                    if (!_isMoving) {
                      _isMoving = true;
                      _pinAnimationController.forward();
                    }
                  });
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  setState(() {
                    _isMoving = false;
                    _pinAnimationController.reverse();
                  });
                  _reverseGeocode(_center);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: Theme.of(context).brightness == Brightness.dark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.carenion',
              ),
            ],
          ),
          // Animated Custom Pin in the center
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 35), // Align tip of pin with center
              child: AnimatedBuilder(
                animation: _pinJumpAnimation,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Shadow
                      Transform.translate(
                        offset: const Offset(0, 35),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: _isMoving ? 12 : 24,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.all(Radius.elliptical(_isMoving ? 6 : 12, 2)),
                          ),
                        ),
                      ),
                      // Pin Icon
                      Transform.translate(
                        offset: Offset(0, _pinJumpAnimation.value),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.person, size: 24, color: Colors.white),
                            ),
                            Container(
                              width: 3,
                              height: 15,
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Search Bar Overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Icon(Icons.search, color: Colors.grey[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Pesquisar local...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(fontSize: 16),
                            ),
                            onSubmitted: _searchAddress,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchResults = [];
                              });
                            },
                          ),
                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Search Results Dropdown
                if (_searchResults.isNotEmpty)
                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(top: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(
                            result['display_name'] ?? 'Desconhecido',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            final lat =
                                double.tryParse(result['lat'].toString()) ??
                                0.0;
                            final lon =
                                double.tryParse(result['lon'].toString()) ??
                                0.0;
                            _moveToLocation(lat, lon);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Address overlay at the bottom
          if (_ready && _searchResults.isEmpty)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                color: Theme.of(context).cardColor.withOpacity(0.95),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isReverseGeocoding 
                                  ? 'A identificar local...' 
                                  : _currentAddress,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Arraste o mapa para o local exato',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _searchResults.isEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isReverseGeocoding ? Colors.grey : Colors.amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: Colors.amber.withOpacity(0.5),
                ),
                onPressed: _isReverseGeocoding ? null : () {
                  Navigator.pop(context, _currentAddress);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isReverseGeocoding)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(Icons.check_circle_outline),
                    const SizedBox(width: 12),
                    Text(
                      _isReverseGeocoding ? 'A identificar local...' : 'Confirmar Este Local',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
