import 'package:desktop_notifications/desktop_notifications.dart';

void main() async {
  var client = NotificationClient();
  var serverInfo = await client.getServerInformation();
  var capabilities = await client.getCapabilities();
  print(
      'Notifications server ${serverInfo.name} implements desktop notifications specification version ${serverInfo.specVersion} and has capabilities $capabilities.');
  await client.close();
}
