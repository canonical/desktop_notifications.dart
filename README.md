[![Pub Package](https://img.shields.io/pub/v/desktop_notifications.svg)](https://pub.dev/packages/desktop_notifications)

Allows notifications to be sent on Linux desktops using the [desktop notifications specification](https://developer.gnome.org/notification-spec/).

```dart
import 'package:dbus/dbus.dart';
import 'package:desktop_notifications/desktop_notifications.dart';

var sessionBus = DBusClient.session();
var client = NotificationClient(sessionBus);
await client.notify('Hello World!');
await sessionBus.disconnect();
```
