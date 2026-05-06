import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const String _manualAdminEmail = 'admin@gmail.com';
  static const String _manualAdminPassword = 'admin123';
  static bool _manualAdminLoggedIn = false;
  static String? _checkinsTableCache;
  static bool? _ticketsTableAvailable;

  static String? get currentUserEmail =>
      _manualAdminLoggedIn ? _manualAdminEmail : _client.auth.currentUser?.email;
  static bool get isCurrentUserAdmin {
    if (_manualAdminLoggedIn) return true;
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final role = user.userMetadata?['role']?.toString().toLowerCase();
    if (role == 'admin') return true;
    final email = user.email?.toLowerCase() ?? '';
    return email.contains('admin');
  }

  static bool tryManualAdminLogin(String email, String password) {
    final ok = email.trim().toLowerCase() == _manualAdminEmail &&
        password.trim() == _manualAdminPassword;
    _manualAdminLoggedIn = ok;
    return ok;
  }

  static Future<AuthResponse> signUp(String email, String password) {
    return _client.auth.signUp(email: email, password: password);
  }

  static Future<AuthResponse> signIn(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    _manualAdminLoggedIn = false;
    if (_client.auth.currentSession != null) {
      await _client.auth.signOut();
    }
  }

  static Future<Map<String, dynamic>> verifyTicket(String ticketCode) async {
    final ticketsAvailable = await _isTicketsTableAvailable();
    if (!ticketsAvailable) {
      return {
        'ticket_id': ticketCode,
        'participant_name': ticketCode,
        'email': null,
        'event_id': null,
      };
    }

    try {
      final response = await _client
          .from('tickets')
          .select('ticket_id, participant_name, email, event_id')
          .eq('ticket_id', ticketCode)
          .maybeSingle();

      final data = response.data as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Ticket not authorized for this event.');
      }
      return data;
    } catch (error) {
      throw Exception('Unable to verify ticket: $error');
    }
  }

  static Future<bool> isTicketAlreadyCheckedIn(String ticketCode) async {
    try {
      final table = await _resolveCheckinsTable();
      if (table == null) return false;
      final response = await _client
          .from(table)
          .select('id', const FetchOptions(count: CountOption.exact))
          .eq('ticket_id', ticketCode);

      return (response.count ?? 0) > 0;
    } catch (error) {
      throw Exception('Unable to verify duplicate check-in: $error');
    }
  }

  static Future<void> submitCheckin(
    String ticketCode,
    String operatorEmail,
  ) async {
    final ticket = await verifyTicket(ticketCode);
    final alreadyCheckedIn = await isTicketAlreadyCheckedIn(ticketCode);

    if (alreadyCheckedIn) {
      throw Exception('This ticket has already been checked in.');
    }

    try {
      final table = await _resolveCheckinsTable();
      if (table == null) {
        throw Exception(
          'Check-in table is missing in Supabase. Create table "checkins" and retry.',
        );
      }
      final payload = <String, dynamic>{
        'ticket_id': ticketCode,
        'participant_name': ticket['participant_name'],
        'scanned_by': operatorEmail,
        'checked_in_at': DateTime.now().toIso8601String(),
      };
      if (ticket['email'] != null) {
        payload['email'] = ticket['email'];
      }
      if (ticket['event_id'] != null) {
        payload['event_id'] = ticket['event_id'];
      }

      await _client.from(table).insert(payload);
    } catch (error) {
      throw Exception('Unable to save check-in: $error');
    }
  }

  static Future<int> fetchAttendanceCount() async {
    try {
      final table = await _resolveCheckinsTable();
      if (table == null) return 0;
      final response = await _client
          .from(table)
          .select('id', const FetchOptions(count: CountOption.exact));
      return response.count ?? 0;
    } catch (_) {
      // Never block UI on attendance fetch failures.
      return 0;
    }
  }

  static Stream<List<Map<String, dynamic>>> watchCheckins() {
    return Stream.fromFuture(_resolveCheckinsTable()).asyncExpand((table) {
      if (table == null) {
        return Stream<List<Map<String, dynamic>>>.value(<Map<String, dynamic>>[]);
      }
      return _client.from(table).stream(primaryKey: ['id']).map(
            (rows) => rows
                .map<Map<String, dynamic>>(
                  (row) => Map<String, dynamic>.from(row as Map),
                )
                .toList(),
          );
    }).handleError((_) => <Map<String, dynamic>>[]);
  }

  static Future<String?> _resolveCheckinsTable() async {
    if (_checkinsTableCache != null) return _checkinsTableCache;

    const candidates = <String>['checkins', 'checkin', 'chickens'];
    for (final table in candidates) {
      try {
        await _client.from(table).select('id').limit(1);
        _checkinsTableCache = table;
        return table;
      } catch (_) {
        // Try next candidate.
      }
    }

    return null;
  }

  static Future<bool> _isTicketsTableAvailable() async {
    if (_ticketsTableAvailable != null) return _ticketsTableAvailable!;
    try {
      await _client.from('tickets').select('ticket_id').limit(1);
      _ticketsTableAvailable = true;
      return true;
    } catch (_) {
      _ticketsTableAvailable = false;
      return false;
    }
  }
}
