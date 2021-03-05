import 'package:desktop_notifications/desktop_notifications.dart';

void main() async {
  var client = NotificationClient();
  await client.notify('Morpheus',
      body:
          'You take the blue pill...the story ends, you wake up in your bed and believe whatever you want to believe. You take the red pill...you stay in Wonderland, and I show you how deep the rabbit hole goes.',
      actions: [
        NotificationAction('red-pill', 'Red Pill'),
        NotificationAction('blue-pill', 'Blue Pill')
      ], actionCallback: (action) async {
    print('You chose $action');
    await client.close();
  });
}
