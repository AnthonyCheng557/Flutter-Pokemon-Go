import 'package:audioplayers/audioplayers.dart';
import 'global.dart';

final player = AudioPlayer();


Future<void> playSoundFromAssets() async {
  if(isSoundEnabled) {
    try {
      await player.play(AssetSource('click_sound.mp3'));
    } catch (e) {
      print('Error playing sound: $e');
    }

  }

}