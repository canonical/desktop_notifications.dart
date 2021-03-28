import 'package:desktop_notifications/desktop_notifications.dart';

void main() async {
  var client = NotificationsClient();

  // Close our own notification after one second.
  var notification = await client.notify('Changed my mind');
  await Future.delayed(Duration(seconds: 1));
  await notification.close();

  await client.close();
}
