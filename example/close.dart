import 'package:desktop_notifications/desktop_notifications.dart';

void main() async {
  var client = NotificationsClient();
  await client.notify('Close Me!', expireTimeoutMs: 5000,
      closedCallback: (reason) async {
    print('Notification closed due to reason $reason');
    await client.close();
  });
}
