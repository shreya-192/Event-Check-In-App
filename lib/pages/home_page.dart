import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _defaultCapacity = 650;
  bool _isOnline = true;
  int _attendanceCount = 0;
  int _capacity = _defaultCapacity;
  String _eventName = 'Smart Event';
  DateTime? _eventDateTime;
  late final Stream<List<Map<String, dynamic>>> _attendanceStream;

  @override
  void initState() {
    super.initState();
    _attendanceStream = SupabaseService.watchCheckins();
    _initializeConnectivity();
    _loadCachedAttendance();
    _loadEventConfig();
  }

  Future<void> _initializeConnectivity() async {
    final status = await Connectivity().checkConnectivity();
    _updateOnlineState(status);
    Connectivity().onConnectivityChanged.listen(_updateOnlineState);
  }

  void _updateOnlineState(ConnectivityResult result) {
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
  }

  void _loadCachedAttendance() {
    final snapshot = LocalStorageService.getAttendanceSnapshot();
    setState(() {
      _attendanceCount = snapshot['count'] as int? ?? 0;
      _capacity = snapshot['capacity'] as int? ?? _defaultCapacity;
    });
  }

  void _loadEventConfig() {
    final config = LocalStorageService.getEventConfig();
    if (config == null) return;
    setState(() {
      _eventName = (config['name'] as String?)?.trim().isNotEmpty == true
          ? config['name'] as String
          : _eventName;
      _eventDateTime = (config['dateTime'] as String?) != null
          ? DateTime.tryParse(config['dateTime'] as String)
          : null;
      _capacity = (config['capacity'] as int?) ?? _capacity;
    });
  }

  Future<void> _syncPendingIfOnline() async {
    if (!_isOnline) return;
    final pending = LocalStorageService.getPendingCheckins();
    for (final entry in pending) {
      try {
        await SupabaseService.submitCheckin(
          entry['ticket_id'] as String,
          entry['operator'] as String? ?? 'offline_sync',
        );
        await LocalStorageService.removePendingCheckin(entry['id'] as String);
      } catch (_) {
        // Keep failed entries for retry.
      }
    }
  }

  void _logout() async {
    await SupabaseService.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = LocalStorageService.getPendingCheckins().length;
    final availableSeats = (_capacity - _attendanceCount).clamp(0, _capacity);
    final dt = _eventDateTime;
    final whenText = dt == null
        ? 'Not set'
        : '${dt.toLocal().year.toString().padLeft(4, '0')}-'
            '${dt.toLocal().month.toString().padLeft(2, '0')}-'
            '${dt.toLocal().day.toString().padLeft(2, '0')} '
            '${dt.toLocal().hour.toString().padLeft(2, '0')}:'
            '${dt.toLocal().minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Event Dashboard'),
        elevation: 0,
        backgroundColor: Colors.lightBlue.shade600,
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _syncPendingIfOnline();
          setState(() {});
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    Colors.lightBlue.shade400,
                    Colors.lightBlue.shade200,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _eventName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When: $whenText',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatusBadge(
                        label: _isOnline ? 'Online' : 'Offline',
                        color: _isOnline
                            ? Colors.blueAccent.shade400
                            : Colors.orangeAccent.shade400,
                      ),
                      const SizedBox(width: 12),
                      _buildStatusBadge(
                        label: pendingCount > 0
                            ? '$pendingCount pending'
                            : 'No pending',
                        color: Colors.white24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetric('Attendance', '$_attendanceCount'),
                    _buildMetric('Capacity', '$_capacity'),
                    _buildMetric('Open', '$availableSeats'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: const Text('Event Setup'),
              onPressed: () async {
                final changed = await Navigator.pushNamed(
                  context,
                  '/event-setup',
                );
                if (changed == true) {
                  _loadEventConfig();
                  LocalStorageService.saveAttendanceSnapshot(_attendanceCount, _capacity);
                }
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.lightBlue.shade700,
              ),
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('Enter Check-In'),
              onPressed: () async {
                await Navigator.pushNamed(context, '/checkin');
                await _syncPendingIfOnline();
                _loadEventConfig();
              },
            ),
            const SizedBox(height: 22),
            Text(
              'Recent Check-ins',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _attendanceStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      _attendanceCount = snapshot.data!.length;
                      LocalStorageService.saveAttendanceSnapshot(
                        _attendanceCount,
                        _capacity,
                      );
                    }

                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Text(
                            'No check-ins recorded yet.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: items.map((item) {
                        final checkedInAt = item['checked_in_at'] as String?;
                        final parsedTime = checkedInAt != null
                            ? DateTime.tryParse(checkedInAt)
                            : null;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.shade100,
                            child: const Icon(
                              Icons.person_outline,
                              color: Colors.indigo,
                            ),
                          ),
                          title: Text(
                            item['participant_name'] as String? ??
                                item['ticket_id'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Ticket: ${item['ticket_id'] ?? 'Unknown'}',
                          ),
                          trailing: Text(
                            parsedTime != null
                                ? '${parsedTime.toLocal().hour.toString().padLeft(2, '0')}:${parsedTime.toLocal().minute.toString().padLeft(2, '0')}'
                                : '',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
