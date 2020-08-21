import 'package:dbus/dbus.dart';
import 'package:desktop_notifications/desktop_notifications.dart';

void main() async {
  var sessionBus = DBusClient.session();
  var client = NotificationClient(sessionBus);
  await client.notify('Close Me!', expireTimeoutMs: 5000,
      closedCallback: (reason) async {
    print('Notification closed due to reason ${reason}');
    await sessionBus.close();
  });
}
