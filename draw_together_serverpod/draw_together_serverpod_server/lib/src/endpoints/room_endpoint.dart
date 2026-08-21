import 'package:serverpod/serverpod.dart';
import '../generated/future_calls.dart';
import '../generated/protocol.dart';
import 'dart:math';

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
  Future<bool> startGame(
    Session session,
    int roomId,
    int durationSeconds,
  ) async {
    // A room only ever moves WAITING -> PLAYING -> FINISHED, so starting a
    // game that is already running or over is refused.
    final room = await Room.db.findById(session, roomId);
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
    }

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
