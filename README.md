[![Pub Package](https://img.shields.io/pub/v/desktop_notifications.svg)](https://pub.dev/packages/desktop_notifications)
[![codecov](https://codecov.io/gh/canonical/desktop_notifications.dart/branch/main/graph/badge.svg?token=QW1N0AQQOY)](https://codecov.io/gh/canonical/desktop_notifications.dart)

Allows notifications to be sent on Linux desktops using the [desktop notifications specification](https://specifications.freedesktop.org/notification-spec/).

```dart
import 'package:desktop_notifications/desktop_notifications.dart';

var client = NotificationsClient();
await client.notify('Hello World!');
await client.close();
```

## Contributing to desktop_notifications.dart

We welcome contributions! See the [contribution guide](CONTRIBUTING.md) for more details.
