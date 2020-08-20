import 'package:dbus/dbus.dart';
import 'package:desktop_notifications/desktop_notifications.dart';

void main() async {
  var sessionBus = DBusClient.session();
  var client = NotificationsClient(sessionBus);
  await client.notify('Hello World!');
  await sessionBus.disconnect();
}
