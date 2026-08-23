import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/serverpod_client.dart';
import '../game_providers.dart';

final targetImageControllerProvider = Provider<TargetImageController>(
  (ref) => TargetImageController(ref),
);

/// Fetches this client's reference image.
///
/// It is a request/response call rather than something delivered on the room
/// channel, because the channel is a broadcast: a per-player crop posted there
/// would reach every subscriber. That also means the fetch survives a
/// reconnect with no replay logic — it is asked for whenever the client finds
/// itself in a running game, whether it saw the transition or not.
class TargetImageController {
  final Ref ref;

  TargetImageController(this.ref);

  /// Loads the reference for the current room and player.
  ///
  /// A room with no target answers with nothing, which is a normal outcome and
  /// not a failure: the round plays exactly as it did before targets existed.
  /// A call that throws is recorded as a failure so the thumbnail can offer a
  /// retry rather than the screen blocking on it.
  Future<void> load() async {
    final roomId = ref.read(roomProvider)?.id;
    final playerId = ref.read(currentPlayerProvider)?.id;
    if (roomId == null || playerId == null) return;

    final notifier = ref.read(targetImageProvider.notifier);
    notifier.loading();
    try {
      final part = await client.room.getTargetImagePart(roomId, playerId);
      if (part == null) {
        notifier.set(null);
        return;
      }
      notifier.set(
        Uint8List.fromList(
          part.bytes.buffer.asUint8List(
            part.bytes.offsetInBytes,
            part.bytes.lengthInBytes,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error fetching the target image: $e');
      notifier.failed();
    }
  }

  /// Loads the whole target for the reveal on the result screen.
  ///
  /// A drawing player only ever held their own crop, so this asks for the
  /// host's part — which is the full normalized image — rather than reusing
  /// what is already on this client. A room that had no target, or a fetch
  /// that fails, leaves the composite on its own; neither is worth
  /// interrupting the reveal for.
  Future<void> loadReveal() async {
    final room = ref.read(roomProvider);
    final roomId = room?.id;
    if (room == null || roomId == null) return;

    try {
      final part = await client.room.getTargetImagePart(roomId, room.hostId);
      if (part == null) return;
      ref
          .read(revealedTargetProvider.notifier)
          .set(
            Uint8List.fromList(
              part.bytes.buffer.asUint8List(
                part.bytes.offsetInBytes,
                part.bytes.lengthInBytes,
              ),
            ),
          );
    } catch (e) {
      debugPrint('Error fetching the target image for the reveal: $e');
    }
  }
}
