import 'package:serverpod/serverpod.dart';
import '../composition/target_image_slicer.dart';
import '../future_calls/game_end_future_call.dart';
import '../generated/future_calls.dart';
import '../generated/protocol.dart';
import 'dart:math';
import 'dart:typed_data';

/// The shortest and longest round the server will schedule.
///
/// Short enough for a quick warm-up round, long enough for a real drawing
/// session, and bounded at all because `startGame` schedules a future call
/// against the value: an unbounded duration is an unbounded row in the
/// scheduler for a room nobody will ever come back to.
const int minRoundSeconds = 10;
const int maxRoundSeconds = 3600;

class RoomEndpoint extends Endpoint {
  /// Create a new room and become host
  Future<Room?> createRoom(
    Session session,
    String hostName,
    double canvasWidth,
    double canvasHeight,
  ) async {
    // Generate a random room code (e.g., 6 uppercase letters)
    final roomCode = _generateRoomCode();

    // We create the room first
    var room = Room(
      roomCode: roomCode,
      hostId: 0, // Will update after player is created
      status: 'WAITING',
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
    );

    // Insert room
    room = await Room.db.insertRow(session, room);
    if (room.id == null) return null;

    // Create the host player. The host observes and controls the session and
    // never draws, so its region fields stay null for the room's whole life.
    var hostPlayer = Player(
      roomId: room.id!,
      name: hostName,
      colorInfo: '0xFFFF0000', // Default red
    );

    hostPlayer = await Player.db.insertRow(session, hostPlayer);

    // Update room hostId
    room = room.copyWith(hostId: hostPlayer.id!);
    room = await Room.db.updateRow(session, room);

    return room;
  }

  /// Join an existing WAITING room by code
  Future<Player?> joinRoom(
    Session session,
    String roomCode,
    String playerName,
  ) async {
    // The status is part of the lookup, so a room that is already PLAYING or
    // FINISHED simply has no match: a game in progress cannot be joined.
    final roomInfo = await Room.db.findFirstRow(
      session,
      where: (r) => r.roomCode.equals(roomCode) & r.status.equals('WAITING'),
    );

    if (roomInfo == null) return null; // Room not found or not waiting

    // Calculate a random default color
    final colors = [
      '0xFF00FF00',
      '0xFF0000FF',
      '0xFFFFFF00',
      '0xFFFF00FF',
      '0xFF00FFFF',
    ];
    final randomColor = colors[Random().nextInt(colors.length)];

    // Regions are assigned when the game starts, not at join time.
    var newPlayer = Player(
      roomId: roomInfo.id!,
      name: playerName,
      colorInfo: randomColor,
    );

    newPlayer = await Player.db.insertRow(session, newPlayer);

    // Notify clients in the room via stream that a new player joined (if they are connected)
    await session.messages.postMessage(
      'room_${roomInfo.id}',
      GameStateChangeMsg(
        roomId: roomInfo.id!,
        status: 'PLAYER_JOINED',
      ), // Quick hack: signal to refresh
    );

    return newPlayer;
  }

  /// Start the game: partition canvas and update states
  ///
  /// Host-only, and only from `WAITING`. The duration is the host's choice
  /// rather than a constant, so it is checked against the supported range here
  /// — the client's picker is a convenience, not the boundary.
  Future<bool> startGame(
    Session session,
    int roomId,
    int playerId,
    int durationSeconds,
  ) async {
    if (durationSeconds < minRoundSeconds ||
        durationSeconds > maxRoundSeconds) {
      return false;
    }

    // A room only ever moves WAITING -> PLAYING -> FINISHED (with PAUSED in
    // between), so starting a game that is already running or over is refused.
    final room = await _hostRoom(session, roomId, playerId);
    if (room == null || room.status != 'WAITING') return false;

    // Get all players
    final players = await Player.db.find(
      session,
      where: (p) => p.roomId.equals(roomId),
      orderBy: (p) => p.id,
    );

    // The host observes rather than draws, so it is not given a region. With
    // no one to draw there is no game to start.
    final drawers = players.where((p) => p.id != room.hostId).toList();
    if (drawers.isEmpty) return false;

    // -- Canvas Partitioning Algorithm --
    // Regions are normalized fractions of the canvas, so the grid is laid out
    // over the unit square and does not depend on canvasWidth/canvasHeight.
    int n = drawers.length;
    // Simple heuristic: find a grid near sqrt(n)
    int cols = sqrt(n).ceil();
    int rows = (n / cols).ceil();

    double colWidth = 1.0 / cols;
    double rowHeight = 1.0 / rows;

    // `drawers` preserves the ascending-id order of the query, which makes the
    // assignment deterministic.
    final assigned = <Player>[];
    for (int i = 0; i < n; i++) {
      int r = i ~/ cols;
      int c = i % cols;

      var p = drawers[i];
      p = p.copyWith(
        regionX: c * colWidth,
        regionY: r * rowHeight,
        regionWidth: colWidth,
        regionHeight: rowHeight,
      );
      await Player.db.updateRow(session, p);
      assigned.add(p);
    }

    await _sliceTargetForRegions(session, roomId, assigned);

    // Update Room
    final endTime = DateTime.now().add(Duration(seconds: durationSeconds));
    final updatedRoom = room.copyWith(status: 'PLAYING', endTime: endTime);
    await Room.db.updateRow(session, updatedRoom);

    // The end of the game is the server's to decide. Client countdowns are
    // presentational from here on: they never finalize anything.
    await session.serverpod.futureCalls
        .callAtTime(endTime.toUtc(), identifier: 'game_end_$roomId')
        .gameEnd
        .finalizeRoom(roomId);

    // Broadcast via pub-sub
    await session.messages.postMessage(
      'room_$roomId',
      GameStateChangeMsg(roomId: roomId, status: 'PLAYING', endTime: endTime),
    );

    return true;
  }

  /// Freezes a running game: the clock stops and no stroke can be written.
  ///
  /// The remainder is banked rather than a running total of paused time, so
  /// the room row answers "how long is left" directly in both states —
  /// `endTime` while playing, `remainingMs` while paused — and the countdown
  /// has exactly two cases. Clearing `endTime` is what makes "an endTime is a
  /// live deadline" true unconditionally, so nothing can schedule against, or
  /// count down to, a suspended one.
  Future<bool> pauseGame(Session session, int roomId, int playerId) async {
    final room = await _hostRoom(session, roomId, playerId);
    if (room == null || room.status != 'PLAYING') return false;

    final endTime = room.endTime;
    final remainingMs = endTime == null
        ? 0
        : max(0, endTime.toUtc().difference(DateTime.now().toUtc()).inMilliseconds);

    await Room.db.updateRow(
      session,
      room.copyWith(
        status: 'PAUSED',
        pausedAt: DateTime.now(),
        remainingMs: remainingMs,
        endTime: null,
      ),
    );

    // Cancelling is best-effort by design: a call already picked up will find
    // the room PAUSED and do nothing, because the row is the authority.
    await session.serverpod.futureCalls.cancel('game_end_$roomId');

    await session.messages.postMessage(
      'room_$roomId',
      GameStateChangeMsg(
        roomId: roomId,
        status: 'PAUSED',
        endTime: null,
        remainingMs: remainingMs,
      ),
    );

    session.log('Paused room $roomId with ${remainingMs}ms left');
    return true;
  }

  /// Restarts a paused game from the moment it was frozen.
  ///
  /// The new deadline is the banked remainder from now, so total drawing time
  /// is preserved exactly however long the pause lasted; only the round's
  /// wall-clock length grows.
  Future<bool> resumeGame(Session session, int roomId, int playerId) async {
    final room = await _hostRoom(session, roomId, playerId);
    if (room == null || room.status != 'PAUSED') return false;

    final endTime = DateTime.now().add(
      Duration(milliseconds: room.remainingMs ?? 0),
    );

    await Room.db.updateRow(
      session,
      room.copyWith(
        status: 'PLAYING',
        endTime: endTime,
        pausedAt: null,
        remainingMs: null,
      ),
    );

    // The same identifier the start scheduled under, so a room never has two
    // live end-of-game calls.
    await session.serverpod.futureCalls
        .callAtTime(endTime.toUtc(), identifier: 'game_end_$roomId')
        .gameEnd
        .finalizeRoom(roomId);

    await session.messages.postMessage(
      'room_$roomId',
      GameStateChangeMsg(roomId: roomId, status: 'PLAYING', endTime: endTime),
    );

    session.log('Resumed room $roomId until $endTime');
    return true;
  }

  /// Ends a running or paused game now.
  ///
  /// This takes the deadline's own path with the "has the clock run out" check
  /// waived, so a game the host ended and one that ran out are byte-identical
  /// in their outcome: same status write, same broadcast order, same
  /// composite.
  Future<bool> stopGame(Session session, int roomId, int playerId) async {
    final room = await _hostRoom(session, roomId, playerId);
    if (room == null) return false;
    if (room.status != 'PLAYING' && room.status != 'PAUSED') return false;

    await session.serverpod.futureCalls.cancel('game_end_$roomId');
    await GameEndFutureCall().finalizeRoom(
      session,
      roomId,
      ignoreDeadline: true,
    );

    session.log('Stopped room $roomId early');
    return true;
  }

  /// Cuts the room's target into one crop per drawing player and stores each
  /// against its owner.
  ///
  /// The crops are computed from the regions assigned in this same
  /// `startGame` call, and are the only copy of that slicing decision from
  /// here on. Regions are assigned once and never change today, and this
  /// depends on it: if regions ever become reassignable mid-game, these rows
  /// go stale and must be regenerated in the same transaction as the
  /// reassignment.
  ///
  /// A room with no target is not an error — the game is playable without one,
  /// so this simply produces nothing.
  Future<void> _sliceTargetForRegions(
    Session session,
    int roomId,
    List<Player> drawers,
  ) async {
    final target = await TargetImage.db.findFirstRow(
      session,
      where: (t) => t.roomId.equals(roomId) & t.playerId.equals(null),
    );
    if (target == null) return;

    // Any crops from an earlier start of this room would name regions that no
    // longer hold.
    await TargetImage.db.deleteWhere(
      session,
      where: (t) => t.roomId.equals(roomId) & t.playerId.notEquals(null),
    );

    final source = target.bytes.buffer.asUint8List(
      target.bytes.offsetInBytes,
      target.bytes.lengthInBytes,
    );

    for (final drawer in drawers) {
      final id = drawer.id;
      final x = drawer.regionX;
      final y = drawer.regionY;
      final width = drawer.regionWidth;
      final height = drawer.regionHeight;
      if (id == null || x == null || y == null || width == null ||
          height == null) {
        continue;
      }

      final crop = cropTargetImage(
        source,
        left: x,
        top: y,
        width: width,
        height: height,
      );
      if (crop == null) continue;

      await TargetImage.db.insertRow(
        session,
        TargetImage(
          roomId: roomId,
          playerId: id,
          bytes: ByteData.view(crop.bytes.buffer),
          mimeType: targetImageMimeType,
          width: crop.width,
          height: crop.height,
        ),
      );
    }

    session.log('Sliced the target for room $roomId into ${drawers.length} '
        'region crop(s)');
  }

  /// The image this player is entitled to see: the whole target for the host,
  /// that player's own crop for a drawing player, and nothing for anyone else.
  ///
  /// This is a request/response call rather than a channel message on purpose.
  /// `room_<id>` is a broadcast, so a crop posted there would reach every
  /// subscriber, which is precisely what cropping exists to prevent.
  Future<TargetImage?> getTargetImagePart(
    Session session,
    int roomId,
    int playerId,
  ) async {
    final room = await Room.db.findById(session, roomId);
    if (room == null) return null;

    // The host observes rather than draws, so there is nothing to withhold.
    if (room.hostId == playerId) {
      return TargetImage.db.findFirstRow(
        session,
        where: (t) => t.roomId.equals(roomId) & t.playerId.equals(null),
      );
    }

    // A player id that belongs to some other room gets nothing, whatever crops
    // exist under it elsewhere.
    final player = await Player.db.findById(session, playerId);
    if (player == null || player.roomId != roomId) return null;

    return TargetImage.db.findFirstRow(
      session,
      where: (t) => t.roomId.equals(roomId) & t.playerId.equals(playerId),
    );
  }

  /// Loads a room and confirms the caller is its host, or returns null.
  ///
  /// Every session command goes through here, so the authorization decision is
  /// made in exactly one place. It is an identity assertion over a `playerId`
  /// the caller supplies, not authentication — the same class of check the rest
  /// of the app already relies on. A `playerId` that is the host of a
  /// *different* room fails too, because the comparison is against the named
  /// room's own `hostId`.
  Future<Room?> _hostRoom(Session session, int roomId, int playerId) async {
    final room = await Room.db.findById(session, roomId);
    if (room == null || room.hostId != playerId) {
      session.log(
        'Refused a session command on room $roomId from player $playerId: '
        'not the host',
        level: LogLevel.warning,
      );
      return null;
    }
    return room;
  }

  /// Stores the picture the room is collectively drawing.
  ///
  /// Host-only, and only while the room is still `WAITING`: the crops are cut
  /// from this image when the game starts, so changing it afterwards would
  /// leave every player's reference disagreeing with the target. The upload is
  /// normalized to the room's canvas aspect and re-encoded as PNG before it is
  /// stored, and a room holds at most one target, so this replaces whatever
  /// was there.
  Future<bool> uploadTargetImage(
    Session session,
    int roomId,
    int playerId,
    ByteData bytes,
  ) async {
    final room = await _hostRoom(session, roomId, playerId);
    if (room == null || room.status != 'WAITING') return false;

    // The cap is checked before decoding, so an oversized upload costs a
    // length comparison rather than a full raster in memory.
    final raw = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    if (raw.isEmpty || raw.length > maxTargetImageBytes) return false;

    final normalized = normalizeTargetImage(
      raw,
      room.canvasHeight <= 0 ? 1.0 : room.canvasWidth / room.canvasHeight,
    );
    // Anything that does not decode as an image is refused with no row written.
    if (normalized == null) return false;

    // Clearing every row for the room, not just the original, is what keeps a
    // re-upload from leaving crops of the previous target behind.
    await TargetImage.db.deleteWhere(
      session,
      where: (t) => t.roomId.equals(roomId),
    );

    await TargetImage.db.insertRow(
      session,
      TargetImage(
        roomId: roomId,
        // The room's original: the whole picture, owned by no one.
        playerId: null,
        bytes: ByteData.view(normalized.bytes.buffer),
        mimeType: targetImageMimeType,
        width: normalized.width,
        height: normalized.height,
      ),
    );

    session.log(
      'Stored a ${normalized.width}x${normalized.height} target for room '
      '$roomId',
    );
    return true;
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  /// Get player by ID
  Future<Player?> getPlayer(Session session, int playerId) async {
    return await Player.db.findById(session, playerId);
  }

  /// Get room by ID
  Future<Room?> getRoom(Session session, int roomId) async {
    return await Room.db.findById(session, roomId);
  }

  /// Get players in a room
  Future<List<Player>> getPlayersInRoom(Session session, int roomId) async {
    return await Player.db.find(
      session,
      where: (p) => p.roomId.equals(roomId),
      orderBy: (p) => p.id,
    );
  }
}
