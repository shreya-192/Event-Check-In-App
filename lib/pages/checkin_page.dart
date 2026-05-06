import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_service.dart';

class CheckinPage extends StatefulWidget {
  const CheckinPage({super.key});

  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  final _ticketController = TextEditingController();
  bool _isLoading = false;
  bool _isOnline = true;

  static const _defaultCapacity = 650;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  int _getConfiguredCapacity() {
    final config = LocalStorageService.getEventConfig();
    return (config?['capacity'] as int?) ?? _defaultCapacity;
  }

  Future<void> _enforceCapacityOrThrow({required bool includeThisCheckin}) async {
    final capacity = _getConfiguredCapacity();
    if (capacity <= 0) return;

    if (_isOnline) {
      final current = await SupabaseService.fetchAttendanceCount();
      final projected = current + (includeThisCheckin ? 1 : 0);
      if (projected > capacity) {
        throw Exception('Capacity limit reached. ($current/$capacity checked in)');
      }
      return;
    }

    final snapshot = LocalStorageService.getAttendanceSnapshot();
    final current = snapshot['count'] as int? ?? 0;
    final pending = LocalStorageService.getPendingCheckins().length;
    final projected = current + pending + (includeThisCheckin ? 1 : 0);
    if (projected > capacity) {
      throw Exception(
        'Capacity limit reached (offline estimate). ($projected/$capacity projected)',
      );
    }
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
    Connectivity().onConnectivityChanged.listen((status) {
      setState(() {
        _isOnline = status != ConnectivityResult.none;
      });
    });
  }

  Future<void> _submitCheckin(String ticketCode) async {
    if (ticketCode.isEmpty) {
      _showMessage('Enter a Participant ID.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final trimmed = ticketCode.trim();

      if (LocalStorageService.localTicketExists(trimmed)) {
        throw Exception('Duplicate entry: this Participant ID is already checked in.');
      }

      if (_isOnline) {
        await _enforceCapacityOrThrow(includeThisCheckin: true);
        await SupabaseService.submitCheckin(
          trimmed,
          SupabaseService.currentUserEmail ?? 'organizer',
        );
        await LocalStorageService.addLocallyCheckedInTicket(trimmed);
        _showMessage('Check-in confirmed.');
      } else {
        if (LocalStorageService.pendingTicketExists(trimmed)) {
          throw Exception('Duplicate entry: this Participant ID is already queued.');
        }

        await _enforceCapacityOrThrow(includeThisCheckin: true);

        final id = const Uuid().v4();
        await LocalStorageService.addPendingCheckin({
          'id': id,
          'ticket_id': trimmed,
          'entered_at': DateTime.now().toIso8601String(),
          'operator': SupabaseService.currentUserEmail ?? 'offline_operator',
          'status': 'pending',
        });
        await LocalStorageService.addLocallyCheckedInTicket(trimmed);
        _showMessage(
          'Offline check-in queued. It will sync when connection returns.',
        );
      }
      _ticketController.clear();
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final capacity = _getConfiguredCapacity();
    final snapshot = LocalStorageService.getAttendanceSnapshot();
    final cachedCount = snapshot['count'] as int? ?? 0;
    final pendingCount = LocalStorageService.getPendingCheckins().length;
    final offlineProjected = cachedCount + pendingCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Check-In')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isOnline
                  ? 'Online mode: enter Participant ID.'
                  : 'Offline mode: enter Participant ID and queue check-in.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Capacity: $capacity'),
                  Text(
                    _isOnline ? 'Live count from server' : 'Offline projected: $offlineProjected',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ticketController,
              decoration: const InputDecoration(
                labelText: 'Participant ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _submitCheckin(_ticketController.text),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm Check-In'),
            ),
          ],
        ),
      ),
    );
  }
}
