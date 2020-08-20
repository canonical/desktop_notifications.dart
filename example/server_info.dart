import 'package:dbus/dbus.dart';
import 'package:desktop_notifications/desktop_notifications.dart';

void main() async {
  var sessionBus = DBusClient.session();
  var client = NotificationsClient(sessionBus);
  var serverInfo = await client.getServerInformation();
  var capabilities = await client.getCapabilities();
  print(
      'Notifications server ${serverInfo.name} implements desktop notifications specification version ${serverInfo.specVersion} and has capabilities ${capabilities}.');
  await sessionBus.disconnect();
}
