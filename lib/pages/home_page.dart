import 'package:flutter/material.dart';
import 'idosos_page.dart';
import 'medication_page.dart';
import 'agenda_page.dart';
import 'settings_page.dart';
import 'medicoes_page.dart';
import 'cuidadora_page.dart';
import '../main.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> userData;
  const HomePage({super.key, required this.userData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  bool get _isCuidadora => widget.userData['tipo'] == 'cuidadora';

  Widget _getPage(int index) {
    if (_isCuidadora) {
      switch (index) {
        case 0:
          return IdososPage(userData: widget.userData);
        case 1:
          return MedicamentosPage(userData: widget.userData);
        case 2:
          return AgendaPage(userData: widget.userData);
        case 3:
          return MedicoesPage(userData: widget.userData);
        case 4:
          return SettingsPage(
            settingsService: settingsService,
            userData: widget.userData,
          );
        default:
          return IdososPage(userData: widget.userData);
      }
    } else {
      switch (index) {
        case 0:
          return IdososPage(userData: widget.userData);
        case 1:
          return MedicamentosPage(userData: widget.userData);
        case 2:
          return AgendaPage(userData: widget.userData);
        case 3:
          return MedicoesPage(userData: widget.userData);
        case 4:
          return CuidadoraPage(userData: widget.userData);
        case 5:
          return SettingsPage(
            settingsService: settingsService,
            userData: widget.userData,
          );
        default:
          return IdososPage(userData: widget.userData);
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getPage(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Idosos/as',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.medication_outlined),
            activeIcon: Icon(Icons.medication),
            label: 'Medicação',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Agenda',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.monitor_heart_outlined),
            activeIcon: Icon(Icons.monitor_heart),
            label: 'Medições',
          ),
          if (!_isCuidadora)
            const BottomNavigationBarItem(
              icon: Icon(Icons.assignment_ind_outlined),
              activeIcon: Icon(Icons.assignment_ind),
              label: 'Cuidador(a)',
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Definições',
          ),
        ],
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10.0,
        unselectedFontSize: 9.5,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 10.0,
          fontWeight: FontWeight.bold,
          overflow: TextOverflow.visible,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.normal,
          overflow: TextOverflow.visible,
        ),
        onTap: _onItemTapped,
      ),
    );
  }
}
