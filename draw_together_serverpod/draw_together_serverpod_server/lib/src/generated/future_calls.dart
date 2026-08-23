/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import 'future_calls_generated_models/game_end_future_call_finalize_room_model.dart'
    as _i2;
import 'dart:async' as _i3;
import '../future_calls/game_end_future_call.dart' as _i4;

/// Invokes a future call.
typedef _InvokeFutureCall =
    Future<void> Function(String name, _i1.SerializableModel? object);

extension ServerpodFutureCallsGetter on _i1.Serverpod {
  /// Generated future calls.
  FutureCalls get futureCalls => FutureCalls();
}

class FutureCalls extends _i1.FutureCallDispatch<_FutureCallRef> {
  FutureCalls._();

  factory FutureCalls() {
    return _instance;
  }

  static final FutureCalls _instance = FutureCalls._();

  _i1.FutureCallManager? _futureCallManager;

  String? _serverId;

  String get _effectiveServerId {
    if (_serverId == null) {
      throw StateError('FutureCalls is not initialized.');
    }
    return _serverId!;
  }

  _i1.FutureCallManager get _effectiveFutureCallManager {
    if (_futureCallManager == null) {
      throw StateError('FutureCalls is not initialized.');
    }
    return _futureCallManager!;
  }

  @override
  void initialize(
    _i1.FutureCallManager futureCallManager,
    String serverId,
  ) {
    var registeredFutureCalls = <String, _i1.FutureCall>{
      'GameEndFinalizeRoomFutureCall': GameEndFinalizeRoomFutureCall(),
    };
    _futureCallManager = futureCallManager;
    _serverId = serverId;
    for (final entry in registeredFutureCalls.entries) {
      _futureCallManager?.registerFutureCall(entry.value, entry.key);
    }
  }

  @override
  _FutureCallRef callAtTime(
    DateTime time, {
    String? identifier,
  }) {
    return _FutureCallRef(
      (name, object) {
        return _effectiveFutureCallManager.scheduleFutureCall(
          name,
          object,
          time,
          _effectiveServerId,
          identifier,
        );
      },
    );
  }

  @override
  _FutureCallRef callWithDelay(
    Duration delay, {
    String? identifier,
  }) {
    return _FutureCallRef(
      (name, object) {
        return _effectiveFutureCallManager.scheduleFutureCall(
          name,
          object,
          DateTime.now().toUtc().add(delay),
          _effectiveServerId,
          identifier,
        );
      },
    );
  }

  @override
  Future<void> cancel(String identifier) async {
    await _effectiveFutureCallManager.cancelFutureCall(identifier);
  }
}

class _FutureCallRef {
  _FutureCallRef(this._invokeFutureCall);

  final _InvokeFutureCall _invokeFutureCall;

  late final gameEnd = _GameEndFutureCallDispatcher(_invokeFutureCall);
}

class _GameEndFutureCallDispatcher {
  _GameEndFutureCallDispatcher(this._invokeFutureCall);

  final _InvokeFutureCall _invokeFutureCall;

  Future<void> finalizeRoom(
    int roomId, {
    bool ignoreDeadline = false,
  }) {
    var object = _i2.GameEndFutureCallFinalizeRoomModel(
      roomId: roomId,
      ignoreDeadline: ignoreDeadline,
    );
    return _invokeFutureCall(
      'GameEndFinalizeRoomFutureCall',
      object,
    );
  }
}

/// Closes the room and publishes the composite.
///
/// The status is written and broadcast before the strokes are read, which is
/// what stops a stroke or an undo from landing while the composite is being
/// built.
///
/// [ignoreDeadline] waives the "has the clock run out" question, and only
/// that question: with it set, a room that is `PAUSED` — and so has no
/// deadline at all — finalizes too. It is what a host stopping early
/// asserts, and it is the reason a stopped game and an expired one are the
/// same code path rather than two implementations that have to be kept
/// agreeing. A scheduled call never sets it.
class GameEndFinalizeRoomFutureCall
    extends _i1.FutureCall<_i2.GameEndFutureCallFinalizeRoomModel> {
  @override
  _i3.Future<void> invoke(
    _i1.Session session,
    _i2.GameEndFutureCallFinalizeRoomModel? object,
  ) async {
    if (object != null) {
      await _i4.GameEndFutureCall().finalizeRoom(
        session,
        object.roomId,
        ignoreDeadline: object.ignoreDeadline,
      );
    }
  }
}
