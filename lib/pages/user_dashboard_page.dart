import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_service.dart';

class UserDashboardPage extends StatefulWidget {
  const UserDashboardPage({super.key});

  @override
  State<UserDashboardPage> createState() => _UserDashboardPageState();
}

class _UserDashboardPageState extends State<UserDashboardPage> {
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

  Future<void> _joinEventFromCard(String eventId) async {
    final joined = await LocalStorageService.joinEventById(eventId);
    if (!mounted) return;
    if (joined) {
      _showMessage('Event joined successfully.');
      Navigator.pushNamed(context, '/my-events');
    } else {
      _showMessage('Event already joined. Opening My Events.');
      Navigator.pushNamed(context, '/my-events');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Dashboard'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/my-events'),
            icon: const Icon(Icons.event_note),
            tooltip: 'My Events',
          ),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/my-events'),
              icon: const Icon(Icons.event_available),
              label: const Text('My Events'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Available Events',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_events.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No events available yet.'),
              ),
            )
          else
            ..._events.map((event) {
              final id = (event['id'] as String?) ?? '-';
              final name = (event['name'] as String?) ?? 'Unnamed event';
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
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.lightBlue.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Event ID: $id'),
                      Text('When: $whenText'),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _joinEventFromCard(id),
                          child: const Text('Join Event'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

