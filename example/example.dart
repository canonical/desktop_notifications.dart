import 'package:desktop_notifications/desktop_notifications.dart';

void main() async {
  var client = NotificationsClient();
  await client.notify('Hello World!');
  await client.close();
}
