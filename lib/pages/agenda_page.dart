import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('eventos')
          .select('*, idosos(*, familias(*))')
          .order('data_inicio');

      final Map<DateTime, List<dynamic>> newEvents = {};

      for (var event in response as List) {
        final startDate = DateTime.parse(event['data_inicio']);
        final day = DateTime(startDate.year, startDate.month, startDate.day);

        if (newEvents[day] == null) {
          newEvents[day] = [];
        }
        newEvents[day]!.add({
          ...event,
          'idoso_nome': event['idosos']?['nome'] ?? 'Desconhecido',
          'familia_nome':
              event['idosos']?['familias']?['nome'] ?? 'Sem Família',
        });
      }

      setState(() {
        _events = newEvents;
      });
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
        title: const Text('Agenda de Cuidados'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
        centerTitle: true,
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
              builder: (context) =>
                  AddEventoPage(selectedDate: _selectedDay ?? DateTime.now()),
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

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
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
              title: Text(
                event['titulo'] ?? 'Sem Título',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Idoso: ${event['idoso_nome']} (${event['familia_nome']})\nTipo: ${event['tipo'] ?? 'Outro'}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () => _confirmDelete(event),
              ),
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
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['titulo'] ?? 'Sem Título',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
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
                  'Idoso',
                  '${event['idoso_nome']} (${event['familia_nome']})',
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
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(value, style: const TextStyle(fontSize: 16)),
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
        await _supabase.from('eventos').delete().eq('id', event['id']);
        _fetchEvents();
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro ao eliminar: $e')));
      }
    }
  }
}

class AddEventoPage extends StatefulWidget {
  final DateTime selectedDate;
  const AddEventoPage({super.key, required this.selectedDate});

  @override
  State<AddEventoPage> createState() => _AddEventoPageState();
}

class _AddEventoPageState extends State<AddEventoPage> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final _tituloController = TextEditingController();
  final _descController = TextEditingController();
  final _localController = TextEditingController();

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
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final famRes = await _supabase.from('familias').select().order('nome');
      setState(() {
        _familias = famRes;
      });
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
        _selectedIdosoId = null;
      });
    } catch (e) {
      debugPrint('Erro ao carregar idosos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Evento'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
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
                decoration: const InputDecoration(
                  labelText: 'Família',
                  prefixIcon: Icon(Icons.family_restroom),
                ),
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
                decoration: const InputDecoration(
                  labelText: 'Idoso',
                  prefixIcon: Icon(Icons.person),
                ),
                value: _selectedIdosoId,
                items: _idosos
                    .map(
                      (i) => DropdownMenuItem<int>(
                        value: i['id'],
                        child: Text(i['nome']),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedIdosoId = val),
                validator: (v) => v == null ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título do Evento',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  prefixIcon: Icon(Icons.category),
                ),
                value: _selectedTipo,
                items: ['Consulta', 'Exame', 'Higiene', 'Refeição', 'Outro']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedTipo = val ?? 'Outro'),
              ),
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

      await _supabase.from('eventos').insert({
        'idoso_id': _selectedIdosoId,
        'titulo': _tituloController.text,
        'descricao': _descController.text,
        'tipo': _selectedTipo,
        'data_inicio': startDateTime.toIso8601String(),
        'localizacao': _localController.text,
        'criado_em': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evento marcado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({Key? key}) : super(key: key);

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  LatLng _center = const LatLng(38.7223, -9.1393); // Lisbon center default
  bool _ready = false;
  bool _isSearching = false;
  List<dynamic> _searchResults = [];

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar no Mapa'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.white,
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
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.carenion',
              ),
            ],
          ),
          // Crosshair in the center of the screen
          const Center(
            child: Icon(Icons.location_on, size: 48, color: Colors.red),
          ),

          // Search Bar Overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Pesquisar hospital, clínica, rua...',
                              border: InputBorder.none,
                            ),
                            onSubmitted: _searchAddress,
                          ),
                        ),
                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: () =>
                                _searchAddress(_searchController.text),
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

          // Coordinates overlay at the bottom
          if (_ready && _searchResults.isEmpty)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white.withOpacity(0.9),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Arraste o mapa para focar no local desejado.\nCoord: ${_center.latitude.toStringAsFixed(4)}, ${_center.longitude.toStringAsFixed(4)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _searchResults.isEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                // Return the selected coordinates as a string
                Navigator.pop(
                  context,
                  '${_center.latitude},${_center.longitude}',
                );
              },
              label: const Text(
                'Confirmar Local',
                style: TextStyle(color: Colors.white),
              ),
              icon: const Icon(Icons.check, color: Colors.white),
              backgroundColor: Colors.green,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
