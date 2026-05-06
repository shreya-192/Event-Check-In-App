import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const _pendingBoxName = 'pending_checkins';
  static const _attendanceBoxName = 'attendance_cache';
  static const _eventBoxName = 'event_config';
  static const _checkedInBoxName = 'checkedin_cache';

  static late final Box _pendingBox;
  static late final Box _attendanceBox;
  static late final Box _eventBox;
  static late final Box _checkedInBox;

  static Future<void> initialize() async {
    _pendingBox = await Hive.openBox(_pendingBoxName);
    _attendanceBox = await Hive.openBox(_attendanceBoxName);
    _eventBox = await Hive.openBox(_eventBoxName);
    _checkedInBox = await Hive.openBox(_checkedInBoxName);

    // Seed dummy events only on first run when no events exist.
    final existingEvents = getAllEventConfigs();
    if (existingEvents.isEmpty) {
      final now = DateTime.now();
      await saveEventConfig(
        name: 'Tech Conference',
        dateTime: DateTime(now.year, now.month, now.day + 3, 10, 0),
        capacity: 100,
      );
      await saveEventConfig(
        name: 'Workshop Flutter',
        dateTime: DateTime(now.year, now.month, now.day + 5, 14, 30),
        capacity: 60,
      );
      await saveEventConfig(
        name: 'Hackathon Night',
        dateTime: DateTime(now.year, now.month, now.day + 7, 18, 0),
        capacity: 80,
      );
      await saveEventConfig(
        name: 'Cultural Fest',
        dateTime: DateTime(now.year, now.month, now.day + 10, 9, 30),
        capacity: 200,
      );
      await saveEventConfig(
        name: 'Alumni Meetup',
        dateTime: DateTime(now.year, now.month, now.day + 14, 16, 0),
        capacity: 120,
      );
    }
  }

  static List<Map<String, dynamic>> getPendingCheckins() {
    final raw = _pendingBox.get('pending', defaultValue: <dynamic>[]) as List;
    return raw
        .map<Map<String, dynamic>>(
          (item) => Map<String, dynamic>.from(item as Map),
        )
        .toList();
  }

  static Future<void> addPendingCheckin(Map<String, dynamic> entry) async {
    final pending = getPendingCheckins();
    pending.add(entry);
    await _pendingBox.put('pending', pending);
  }

  static Future<void> removePendingCheckin(String id) async {
    final pending = getPendingCheckins()
        .where((item) => item['id'] != id)
        .toList();
    await _pendingBox.put('pending', pending);
  }

  static Future<void> clearPendingCheckins() async {
    await _pendingBox.put('pending', <dynamic>[]);
  }

  static bool pendingTicketExists(String ticketCode) {
    return getPendingCheckins().any((item) => item['ticket_id'] == ticketCode);
  }

  static Set<String> getLocallyCheckedInTicketIds() {
    final raw = _checkedInBox.get('ticket_ids', defaultValue: <dynamic>[]) as List;
    return raw.map((e) => e.toString()).toSet();
  }

  static bool localTicketExists(String ticketCode) {
    return getLocallyCheckedInTicketIds().contains(ticketCode);
  }

  static Future<void> addLocallyCheckedInTicket(String ticketCode) async {
    final set = getLocallyCheckedInTicketIds();
    set.add(ticketCode);
    await _checkedInBox.put('ticket_ids', set.toList());
  }

  static Future<void> saveAttendanceSnapshot(int count, int capacity) async {
    await _attendanceBox.put('snapshot', {
      'count': count,
      'capacity': capacity,
    });
  }

  static Map<String, dynamic> getAttendanceSnapshot() {
    final snapshot =
        _attendanceBox.get(
              'snapshot',
              defaultValue: {'count': 0, 'capacity': 0},
            )
            as Map;
    return Map<String, dynamic>.from(snapshot);
  }

  static Map<String, dynamic>? getEventConfig() {
    final events = getAllEventConfigs();
    if (events.isNotEmpty) {
      return events.last;
    }

    // Backward compatibility for old single-event storage.
    final legacy = _eventBox.get('event', defaultValue: null);
    if (legacy == null) return null;
    return Map<String, dynamic>.from(legacy as Map);
  }

  static List<Map<String, dynamic>> getAllEventConfigs() {
    final raw = _eventBox.get('events', defaultValue: <dynamic>[]) as List;
    final events = raw
        .map<Map<String, dynamic>>(
          (item) => Map<String, dynamic>.from(item as Map),
        )
        .toList();
    var changed = false;
    for (var i = 0; i < events.length; i++) {
      if ((events[i]['id'] as String?) == null || (events[i]['id'] as String).isEmpty) {
        events[i]['id'] = 'legacy_${i + 1}';
        changed = true;
      }
    }
    if (changed) {
      _eventBox.put('events', events);
    }
    return events;
  }

  static Future<void> saveEventConfig({
    required String name,
    required DateTime dateTime,
    required int capacity,
  }) async {
    final all = getAllEventConfigs();
    final nextId = (all.length + 1).toString();
    final event = {
      'id': nextId,
      'name': name,
      'dateTime': dateTime.toIso8601String(),
      'capacity': capacity,
      'createdAt': DateTime.now().toIso8601String(),
    };

    all.add(event);
    await _eventBox.put('events', all);
    // Keep latest event under old key so existing code still works.
    await _eventBox.put('event', event);
  }

  static List<String> getJoinedEventIds() {
    final raw = _eventBox.get('joined_event_ids', defaultValue: <dynamic>[]) as List;
    return raw.map((e) => e.toString()).toList();
  }

  static Future<bool> joinEventById(String eventIdOrNumber) async {
    final input = eventIdOrNumber.trim();
    if (input.isEmpty) return false;

    final events = getAllEventConfigs();
    if (events.isEmpty) return false;

    String? resolvedId;
    final byId = events.where((event) => (event['id']?.toString() ?? '') == input);
    if (byId.isNotEmpty) {
      resolvedId = byId.first['id']?.toString();
    } else {
      final number = int.tryParse(input);
      if (number != null && number >= 1 && number <= events.length) {
        resolvedId = events[number - 1]['id']?.toString();
      }
    }

    if (resolvedId == null || resolvedId.isEmpty) return false;

    final joined = getJoinedEventIds();
    if (joined.contains(resolvedId)) return false;
    joined.add(resolvedId);
    await _eventBox.put('joined_event_ids', joined);
    return true;
  }

  static List<Map<String, dynamic>> getMyJoinedEvents() {
    final joined = getJoinedEventIds().toSet();
    final events = getAllEventConfigs();
    return events
        .where((event) => joined.contains(event['id']?.toString() ?? ''))
        .toList();
  }
}
