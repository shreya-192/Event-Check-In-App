import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadEventConfig();
  }

  void _loadEventConfig() {
    final events = LocalStorageService.getAllEventConfigs();
    setState(() {
      _events = events;
    });
  }

  Future<void> _logout() async {
    await SupabaseService.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [IconButton(onPressed: _logout, icon: const Icon(Icons.logout))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saved Events',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_events.isEmpty)
                    const Text('No events added yet.')
                  else
                    ..._events.map((event) {
                      final id = (event['id'] as String?) ?? '-';
                      final dt = (event['dateTime'] as String?) != null
                          ? DateTime.tryParse(event['dateTime'] as String)
                          : null;
                      final whenText = dt == null
                          ? 'Not set'
                          : '${dt.toLocal().year.toString().padLeft(4, '0')}-'
                              '${dt.toLocal().month.toString().padLeft(2, '0')}-'
                              '${dt.toLocal().day.toString().padLeft(2, '0')} '
                              '${dt.toLocal().hour.toString().padLeft(2, '0')}:'
                              '${dt.toLocal().minute.toString().padLeft(2, '0')}';
                      final name = (event['name'] as String?) ?? 'Unnamed event';
                      final cap = (event['capacity'] as int?)?.toString() ?? '-';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('Event ID: $id'),
                              Text('When: $whenText'),
                              Text('Capacity: $cap'),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final changed = await Navigator.pushNamed(context, '/event-setup');
              if (changed == true) _loadEventConfig();
            },
            icon: const Icon(Icons.event),
            label: const Text('Add Event'),
          ),
        ],
      ),
    );
  }
}

