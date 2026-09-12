import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../game/engine.dart';
import '../game/models.dart';
import 'settings_service.dart';
import '../firebase_options.dart';

class OnlineUnavailableException implements Exception {
  const OnlineUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OnlineRoomUpdate {
  const OnlineRoomUpdate({
    required this.state,
    required this.hasOpponent,
    required this.opponentConnected,
    required this.expired,
  });

  final GameState state;
  final bool hasOpponent;
  final bool opponentConnected;
  final bool expired;
}

class OnlineRoomHandle {
  OnlineRoomHandle._({
    required this.code,
    required this.localPlayer,
    required this.updates,
    required this._onLeave,
    required this._onMove,
    required this._onRestart,
  });

  final String code;
  final int localPlayer;
  final Stream<OnlineRoomUpdate> updates;
  final Future<void> Function() _onLeave;
  final Future<bool> Function(GameMove move) _onMove;
  final Future<void> Function() _onRestart;

  Future<bool> play(GameMove move) => _onMove(move);
  Future<void> restart() => _onRestart();
  Future<void> leave() => _onLeave();
}

class OnlineService {
  OnlineService({
    CrossmateEngine? engine,
    SettingsService? settings,
    FirebaseAuth? auth,
    FirebaseDatabase? database,
  }) : this._internal(
         engine: engine ?? CrossmateEngine(),
         settings: settings ?? const SettingsService(),
         auth: auth,
         database: database,
       );

  OnlineService._internal({
    required this._engine,
    required this._settings,
    this._auth,
    this._database,
  });

  static const roomLifetime = Duration(days: 10);
  static const version = 'native-0.1.1';
  static const roomRoot = 'crossmateNativeRooms';
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final CrossmateEngine _engine;
  final SettingsService _settings;
  FirebaseAuth? _auth;
  FirebaseDatabase? _database;
  final Random _random = Random.secure();

  Future<void>? _initializeFuture;

  bool get isConfigured =>
      _auth != null && _database != null && _auth!.currentUser != null;

  Future<void> initialize() async {
    if (isConfigured) return;

    final existing = _initializeFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final future = _initializeOnce();
    _initializeFuture = future;

    try {
      await future;
    } finally {
      if (identical(_initializeFuture, future)) {
        _initializeFuture = null;
      }
    }
  }

  Future<void> _initializeOnce() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      _auth ??= FirebaseAuth.instance;
      _database ??= FirebaseDatabase.instance;

      if (_auth!.currentUser == null) {
        final credential = await _auth!.signInAnonymously();

        if (credential.user == null && _auth!.currentUser == null) {
          throw const OnlineUnavailableException(
            'Firebase anonymous sign-in returned no user.',
          );
        }
      }
    } on FirebaseAuthException catch (error) {
      throw OnlineUnavailableException(
        'Firebase sign-in failed (${error.code}): '
        '${error.message ?? 'Unknown authentication error.'}',
      );
    } on FirebaseException catch (error) {
      throw OnlineUnavailableException(
        'Firebase connection failed (${error.code}): '
        '${error.message ?? 'Unknown Firebase error.'}',
      );
    } on OnlineUnavailableException {
      rethrow;
    } catch (error) {
      throw OnlineUnavailableException(
        'Online play could not connect to Firebase.\n\n$error',
      );
    }
  }

  Future<OnlineRoomHandle> createRoom({int boardSize = 9}) async {
    await initialize();
    final uid = _requireUser().uid;
    for (var attempt = 0; attempt < 8; attempt += 1) {
      final code = _randomRoomCode();
      final ref = _database!.ref('$roomRoot/$code');
      final now = DateTime.now().millisecondsSinceEpoch;
      final state = _engine.initialState(boardSize: boardSize);
      final result = await ref.runTransaction((currentValue) {
        if (currentValue != null) return Transaction.abort();
        return Transaction.success(<String, Object?>{
          'version': version,
          'createdAt': now,
          'expiresAt': now + roomLifetime.inMilliseconds,
          'players': <String, Object?>{
            'p1': <String, Object?>{'uid': uid, 'joinedAt': now},
          },
          'state': state.toJson(),
        });
      }, applyLocally: false);
      if (result.committed) return _attach(code, 1);
    }
    throw const OnlineUnavailableException(
      'Could not find a free room code. Try again.',
    );
  }

  Future<OnlineRoomHandle> joinRoom(String rawCode) async {
    await initialize();
    final code = cleanRoomCode(rawCode);
    if (code.length != 5) {
      throw const OnlineUnavailableException(
        'Enter the five-character room code.',
      );
    }
    final ref = _database!.ref('$roomRoot/$code');
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw const OnlineUnavailableException(
        'Room not found. Ask Player 1 to create a new room.',
      );
    }
    final room = _map(snapshot.value);
    final players = _map(room['players']);
    final p1 = _map(players['p1']);
    final p2 = _map(players['p2']);
    final uid = _requireUser().uid;
    final expiresAt = _asInt(room['expiresAt']);
    if (expiresAt < DateTime.now().millisecondsSinceEpoch) {
      throw const OnlineUnavailableException(
        'This room has expired. Ask Player 1 to create a new room.',
      );
    }
    if (p1['uid'] == uid) return _attach(code, 1);
    if (p2['uid'] == uid) return _attach(code, 2);
    if (p2['uid'] != null && p2['uid'].toString().isNotEmpty) {
      throw const OnlineUnavailableException(
        'This room already has two players.',
      );
    }

    final p2Ref = ref.child('players/p2');
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = await p2Ref.runTransaction((currentValue) {
      final current = _map(currentValue);
      final currentUid = current['uid']?.toString();
      if (currentUid == null || currentUid.isEmpty) {
        return Transaction.success(<String, Object?>{
          'uid': uid,
          'joinedAt': now,
        });
      }
      if (currentUid == uid) return Transaction.success(currentValue);
      return Transaction.abort();
    }, applyLocally: false);
    if (!result.committed) {
      throw const OnlineUnavailableException(
        'This room already has two players.',
      );
    }
    return _attach(code, 2);
  }

  String cleanRoomCode(String value) {
    final cleaned = value.toUpperCase().replaceAll(RegExp('[^A-Z2-9]'), '');
    return cleaned.substring(0, min(5, cleaned.length));
  }

  Future<OnlineRoomHandle> _attach(String code, int localPlayer) async {
    final uid = _requireUser().uid;
    final roomRef = _database!.ref('$roomRoot/$code');
    final presenceRef = roomRef.child('presence/$uid');
    final controller = StreamController<OnlineRoomUpdate>();
    StreamSubscription<DatabaseEvent>? subscription;
    var closed = false;

    await presenceRef.set(true);
    await presenceRef.onDisconnect().remove();
    await _settings.saveRoom(code, localPlayer);

    subscription = roomRef.onValue.listen((event) {
      if (closed) return;
      final room = _map(event.snapshot.value);
      final rawState = _map(room['state']);
      if (rawState.isEmpty) {
        controller.addError(
          const OnlineUnavailableException('This room no longer exists.'),
        );
        return;
      }
      try {
        final state = GameState.fromJson(rawState);
        final players = _map(room['players']);
        final p2 = _map(players['p2']);
        final presence = _map(room['presence']);
        final opponent = localPlayer == 1
            ? _map(players['p2'])
            : _map(players['p1']);
        final opponentUid = opponent['uid']?.toString();
        final expiresAt = _asInt(room['expiresAt']);
        controller.add(
          OnlineRoomUpdate(
            state: state,
            hasOpponent: p2['uid'] != null && p2['uid'].toString().isNotEmpty,
            opponentConnected:
                opponentUid != null && presence[opponentUid] == true,
            expired: expiresAt < DateTime.now().millisecondsSinceEpoch,
          ),
        );
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }, onError: controller.addError);

    Future<void> leave() async {
      if (closed) return;
      closed = true;
      await subscription?.cancel();
      try {
        await presenceRef.remove();
      } catch (_) {
        // Presence also clears through onDisconnect.
      }
      await _settings.clearRoom();
      await controller.close();
    }

    Future<bool> play(GameMove proposed) async {
      final result = await roomRef.child('state').runTransaction((
        currentValue,
      ) {
        final raw = _map(currentValue);
        if (raw.isEmpty) return Transaction.abort();
        try {
          final remote = GameState.fromJson(raw);
          if (remote.gameOver || remote.currentPlayer != localPlayer) {
            return Transaction.abort();
          }
          final canonical = _engine.canonicalMove(remote, proposed);
          if (canonical == null) return Transaction.abort();
          return Transaction.success(
            _engine.advance(remote, canonical).toJson(),
          );
        } catch (_) {
          return Transaction.abort();
        }
      }, applyLocally: false);
      return result.committed;
    }

    Future<void> restart() async {
      final result = await roomRef.child('state').runTransaction((
        currentValue,
      ) {
        if (currentValue == null) return Transaction.abort();
        final previous = GameState.fromJson(_map(currentValue));
        return Transaction.success(
          _engine.initialState(boardSize: previous.boardSize).toJson(),
        );
      }, applyLocally: false);
      if (!result.committed) {
        throw const OnlineUnavailableException('Could not start the rematch.');
      }
    }

    return OnlineRoomHandle._(
      code: code,
      localPlayer: localPlayer,
      updates: controller.stream,
      onLeave: leave,
      onMove: play,
      onRestart: restart,
    );
  }

  String _randomRoomCode() {
    return List<String>.generate(
      5,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
      growable: false,
    ).join();
  }

  User _requireUser() {
    final user = _auth?.currentUser;
    if (user == null) {
      throw const OnlineUnavailableException(
        'Online sign-in is not ready. Please try again.',
      );
    }
    return user;
  }
}

Map<Object?, Object?> _map(Object? value) {
  if (value is Map<Object?, Object?>) return value;
  if (value is Map) return Map<Object?, Object?>.from(value);
  return const <Object?, Object?>{};
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
