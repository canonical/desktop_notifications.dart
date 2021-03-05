import 'dart:typed_data';
import 'package:desktop_notifications/desktop_notifications.dart';

void main() async {
  var client = NotificationClient();

  /// Make a simple color gradient icon.
  var pixels = <int>[];
  for (var y = 0; y < 255; y++) {
    for (var x = 0; x < 255; x++) {
      pixels.add(x);
      pixels.add(y);
      pixels.add(255);
    }
  }

  await client.notify('Emergency!!!', hints: [
    NotificationHint.category(NotificationCategory.networkError()),
    NotificationHint.urgency(NotificationUrgency.critical),
    NotificationHint.imageData(255, 255, Uint8List.fromList(pixels))
  ]);

  await client.close();
}
