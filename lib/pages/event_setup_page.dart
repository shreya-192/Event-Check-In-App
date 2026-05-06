import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_service.dart';

class EventSetupPage extends StatefulWidget {
  const EventSetupPage({super.key});

  @override
  State<EventSetupPage> createState() => _EventSetupPageState();
}

class _EventSetupPageState extends State<EventSetupPage> {
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController();

  DateTime? _dateTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (!SupabaseService.isCurrentUserAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only admin can add or edit events.')),
        );
        Navigator.pop(context);
      });
      return;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _dateTime ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;

    if (!mounted) return;
    setState(() {
      _dateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final capacity = int.tryParse(_capacityController.text.trim());

    if (name.isEmpty) {
      _showMessage('Please enter an event name.');
      return;
    }
    if (_dateTime == null) {
      _showMessage('Please pick the event date & time.');
      return;
    }
    if (capacity == null || capacity <= 0) {
      _showMessage('Please enter a valid maximum capacity.');
      return;
    }

    setState(() => _saving = true);
    try {
      await LocalStorageService.saveEventConfig(
        name: name,
        dateTime: _dateTime!,
        capacity: capacity,
      );
      if (!mounted) return;
      _showMessage('Event added successfully.');
      Navigator.pop(context, true);
    } catch (e) {
      _showMessage('Failed to save event: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final dt = _dateTime;
    final dateText = dt == null
        ? 'Pick date & time'
        : '${dt.toLocal().year.toString().padLeft(4, '0')}-'
            '${dt.toLocal().month.toString().padLeft(2, '0')}-'
            '${dt.toLocal().day.toString().padLeft(2, '0')} '
            '${dt.toLocal().hour.toString().padLeft(2, '0')}:'
            '${dt.toLocal().minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Event Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Event Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _saving ? null : _pickDateTime,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date & Time',
                border: OutlineInputBorder(),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateText),
                  const Icon(Icons.calendar_month),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _capacityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Maximum Capacity',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save Event'),
          ),
        ],
      ),
    );
  }
}

