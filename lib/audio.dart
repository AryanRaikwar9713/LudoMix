import 'package:just_audio/just_audio.dart';

class Audio {
  static AudioPlayer audioPlayer = AudioPlayer();

  static Future<void> playMove() async {
    try {
      final duration =
          await audioPlayer.setAsset('assets/sounds/move.wav');
      await audioPlayer.play();
      return Future.delayed(duration ?? Duration.zero);
    } catch (e) {
      // Asset missing / web audio issues should not break game logic
      // Print once in console and continue silently.
      // debugPrint('Audio.playMove error: $e');
      return Future.value();
    }
  }

  static Future<void> playKill() async {
    try {
      final duration =
          await audioPlayer.setAsset('assets/sounds/laugh.mp3');
      await audioPlayer.play();
      return Future.delayed(duration ?? Duration.zero);
    } catch (e) {
      // debugPrint('Audio.playKill error: $e');
      return Future.value();
    }
  }

  static Future<void> rollDice() async {
    try {
      final duration =
          await audioPlayer.setAsset('assets/sounds/roll_the_dice.mp3');
      await audioPlayer.play();
      return Future.delayed(duration ?? Duration.zero);
    } catch (e) {
      // debugPrint('Audio.rollDice error: $e');
      return Future.value();
    }
  }

  /// Turn change sound used in both 4-player and 2v2 modes.
  static Future<void> playTurnChange() async {
    try {
      // Primary: match_found sound as turn indicator
      var duration =
          await audioPlayer.setAsset('assets/sounds/match_found.mp3');
      audioPlayer.play();
      return Future.delayed(duration ?? const Duration(milliseconds: 500));
    } catch (e) {
      // Fallback: roll_dice sound if match_found not available
      try {
        var duration =
            await audioPlayer.setAsset('assets/sounds/roll_the_dice.mp3');
        audioPlayer.play();
        return Future.delayed(duration ?? const Duration(milliseconds: 500));
      } catch (_) {
        return Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }
}
