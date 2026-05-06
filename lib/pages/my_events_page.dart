import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

class MyEventsPage extends StatefulWidget {
  const MyEventsPage({super.key});

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage> {
  List<Map<String, dynamic>> _myEvents = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadMyEvents();
  }

  void _loadMyEvents() {
    setState(() {
      _myEvents = LocalStorageService.getMyJoinedEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Events')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_myEvents.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('You have not joined any event yet.'),
              ),
            )
          else
            ..._myEvents.map((event) {
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
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('Event ID: $id'),
                      Text('When: $whenText'),
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

