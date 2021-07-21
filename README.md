[![Pub Package](https://img.shields.io/pub/v/desktop_notifications.svg)](https://pub.dev/packages/desktop_notifications)

Allows notifications to be sent on Linux desktops using the [desktop notifications specification](https://developer.gnome.org/notification-spec/).

```dart
import 'package:desktop_notifications/desktop_notifications.dart';

var client = NotificationsClient();
await client.notify('Hello World!');
await client.close();
```

## Supported platforms

This package shows on pub.dev as supporting all platforms, not just Linux.
This is because the package doesn't contain any platform specific code that would limit which platforms it can run on.
It however only makes sense on Linux, as the other platforms are not running D-Bus and/or a compliant notification server.
You can safely include this package when writing applications that work on multiple platforms, it will fail with an exception if trying to send a notification if the required services are not present.
There is an [open issue](https://github.com/dart-lang/pub/issues/2353) requesting the ability to be able to show which platforms a package is intended for.

## Contributing to desktop_notifications.dart

We welcome contributions! See the [contribution guide](CONTRIBUTING.md) for more details.
