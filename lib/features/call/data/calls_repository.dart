import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:titra/core/api/api_client.dart';
import 'package:titra/core/local_db/app_database.dart';
import 'package:titra/features/call/data/call_history_entry.dart';
import 'package:flutter/foundation.dart';

/// REST for call sessions (signaling state). Media is WebRTC peer-to-peer.
class CallsRepository {
  CallsRepository(this._api, this._db);

  final ApiClient _api;
  final AppDatabase _db;

  /// WebRTC expects `urls`; some APIs return `url`.
  static Map<String, dynamic> _normalizeIceServer(Map<String, dynamic> m) {
    if (!m.containsKey('urls') && m['url'] != null) {
      m['urls'] = m['url'];
    }
    return m;
  }

  Map<String, dynamic> _unwrapData(Response<dynamic> response) {
    final data = response.data;
    if (data is Map && data['data'] != null && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  /// Returns `iceServers` list for [createPeerConnection] `configuration`.
  Future<List<Map<String, dynamic>>> fetchIceServers() async {
    final response = await _api.get<dynamic>(
      'calls/ice-config',
      showFeedback: false,
    );
    final map = _unwrapData(response);
    final raw = map['iceServers'];
    if (raw is! List) {
      return [
        {'urls': 'stun:stun.l.google.com:19302'},
      ];
    }
    return raw
        .whereType<Map>()
        .map((e) => _normalizeIceServer(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// [type] `AUDIO` or `VIDEO` (server enum).
  Future<Map<String, dynamic>> startCall({
    required String conversationId,
    required String type,
  }) async {
    final response = await _api.post<dynamic>(
      'calls/start',
      data: {'conversationId': conversationId, 'type': type},
      showFeedback: false,
    );
    final map = _unwrapData(response);
    if (map.isEmpty) {
      throw StateError('Empty start call response');
    }
    return map;
  }

  Future<void> joinCall(String callSessionId) async {
    await _api.post<dynamic>(
      'calls/join',
      data: {'callSessionId': callSessionId},
      showFeedback: false,
    );
  }

  Future<void> joinCallWithRetry(
    String callSessionId, {
    String? conversationId,
    int maxAttempts = 6,
    Duration retryDelay = const Duration(milliseconds: 350),
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await joinCall(callSessionId);
        if (attempt > 1) {
          debugPrint(
            '[CallsRepository] joinCall recovered sid=$callSessionId attempt=$attempt',
          );
        }
        return;
      } on DioException catch (e) {
        lastError = e;
        final code = e.response?.statusCode;
        final shouldRetry = (code == 400 || code == 404) && attempt < maxAttempts;
        if (!shouldRetry) rethrow;

        Map<String, dynamic>? activeMatch;
        if (conversationId != null && conversationId.isNotEmpty) {
          try {
            final activeCalls = await fetchActiveCalls(conversationId);
            activeMatch = activeCalls.cast<Map<String, dynamic>?>().firstWhere(
              (call) =>
                  call != null &&
                  (call['id']?.toString() ?? '') == callSessionId,
              orElse: () => null,
            );
          } catch (_) {}
        }

        debugPrint(
          '[CallsRepository] joinCall retry sid=$callSessionId '
          'attempt=$attempt/$maxAttempts status=$code activeMatch=${activeMatch != null} '
          'response=${e.response?.data}',
        );
        await Future<void>.delayed(retryDelay);
      } catch (e) {
        lastError = e;
        rethrow;
      }
    }

    if (lastError is Exception) {
      throw lastError;
    }
    throw StateError('joinCallWithRetry failed for $callSessionId');
  }

  Future<List<Map<String, dynamic>>> fetchActiveCalls(
    String conversationId,
  ) async {
    final response = await _api.get<dynamic>(
      'calls/$conversationId/active',
      showFeedback: false,
    );
    final data = response.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Future<void> leaveCall(String callSessionId) async {
    await _api.post<dynamic>(
      'calls/leave',
      data: {'callSessionId': callSessionId},
      showFeedback: false,
    );
  }

  Future<void> endCall(String callSessionId, {String? reason}) async {
    final body = <String, dynamic>{'callSessionId': callSessionId};
    if (reason != null) {
      body['reason'] = reason;
    }
    await _api.post<dynamic>('calls/end', data: body, showFeedback: false);
  }

  Stream<List<CallHistoryEntry>> watchCallHistory() {
    return _db.callHistoryDao.watchCallHistory().map(
      (rows) => rows.map(_mapLocalEntry).toList(),
    );
  }

  /// Recent ended calls for the logged-in user (missed, answered, declined, etc.).
  Future<List<CallHistoryEntry>> fetchCallHistory({int limit = 50}) async {
    await hydrateCallHistory(limit: limit);
    return watchCallHistory().first;
  }

  Future<void> hydrateCallHistory({int limit = 50}) async {
    final response = await _api.get<dynamic>(
      'calls/history',
      queryParameters: {'limit': limit},
      showFeedback: false,
    );
    final map = _unwrapData(response);
    final raw = map['items'];
    if (raw is! List) {
      return;
    }
    await _db.callHistoryDao.upsertCallHistoryBatch(
      raw.whereType<Map>().map((e) {
        final entry = CallHistoryEntry.fromJson(Map<String, dynamic>.from(e));
        return CallHistoryCompanion.insert(
          id: entry.callSessionId,
          callSessionId: Value(entry.callSessionId),
          conversationId: Value(entry.conversationId),
          peerUserId: Value(entry.peerUserId),
          direction: entry.direction,
          type: entry.callType,
          status: entry.outcome,
          displayTitle: Value(entry.displayTitle),
          avatarUrl: Value(entry.peerAvatarUrl),
          conversationType: Value(entry.conversationType),
          startedAt: Value(entry.createdAt.millisecondsSinceEpoch),
          durationSeconds: Value(entry.durationSec),
          rawJson: Value(Map<String, dynamic>.from(e).toString()),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        );
      }),
    );
  }

  CallHistoryEntry _mapLocalEntry(CallHistoryData row) {
    return CallHistoryEntry(
      callSessionId: row.callSessionId ?? row.id,
      conversationId: row.conversationId ?? '',
      callType: row.type,
      conversationType: row.conversationType ?? 'DIRECT',
      direction: row.direction,
      outcome: row.status,
      displayTitle: row.displayTitle ?? 'Call',
      durationSec: row.durationSeconds,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.startedAt ?? row.updatedAt,
        isUtc: true,
      ),
      peerAvatarUrl: row.avatarUrl,
      peerUserId: row.peerUserId,
    );
  }
}
