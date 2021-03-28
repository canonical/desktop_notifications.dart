import 'package:desktop_notifications/desktop_notifications.dart';

void main() async {
  var client = NotificationsClient();

  // Detect when the user/system closes this notification.
  var notification = await client.notify('Close Me!', expireTimeoutMs: 5000);
  print('Notification closed due to reason ${await notification.closeReason}');

  await client.close();
}
