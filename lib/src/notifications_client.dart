import 'dart:typed_data';
import 'package:dbus/dbus.dart';

/// Contains information reported by the notifications server.
class NotificationServerInformation {
  /// Name of the server.
  final String name;

  /// The vendor of the sever.
  final String vendor;

  /// The version of the server.
  final String version;

  /// The notifications specification version this server implements.
  final String specVersion;

  const NotificationServerInformation(
      this.name, this.vendor, this.version, this.specVersion);

  @override
  String toString() {
    return "NotificationServerInformation(name: '${name}', vendor: '${vendor}', version: '${version}', specVersion: '${specVersion}')";
  }
}

/// Function called when a notification action is invoked.
typedef NotificationActionFunction = void Function(String key);

/// Function called when a notification is closed.
typedef NotificationClosedFunction = void Function(int reason);

/// A hint about how to display this notification.
class NotificationHint {
  /// Unique key for this hint.
  final String key;

  /// The value of this hint.
  final DBusValue value;

  /// Creates a custom notification hint.
  NotificationHint(this.key, this.value);

  /// This notification should have its action IDs intepreted as icon names.
  factory NotificationHint.actionIcons() {
    return NotificationHint('action-icons', DBusBoolean(true));
  }

  /// This notification is of type [category]. FIXME standard types.
  factory NotificationHint.category(String category) {
    return NotificationHint('category', DBusString(category));
  }

  /// This notification is from the application with the desktop file [name].desktop.
  factory NotificationHint.desktopEntry(String name) {
    return NotificationHint('desktop-entry', DBusString(name));
  }

  /// This notification should show use the supplied raw image data for its icon.
  /// [data] is the raw data for the image.
  /// [width] and [height] are the width and height of the image in pixels.
  /// [rowStride] is the number of bytes per row in [data].
  /// [hasAlpha] is true if the image has an alpha channel.
  /// [bitsPerSample] is the number of bits in each color sample.
  /// [channels] is the number of channels in the image (e.g. 3 for RGB, 4 for RGBA).
  factory NotificationHint.imageData(int width, int height, Uint8List data,
      {int rowStride = -1,
      bool hasAlpha = false,
      int bitsPerSample = 8,
      int channels = 3}) {
    if (rowStride < 0) {
      rowStride = ((width * channels * bitsPerSample) / 8).ceil();
    }
    return NotificationHint(
        'image-data',
        DBusStruct([
          DBusInt32(width),
          DBusInt32(height),
          DBusInt32(rowStride),
          DBusBoolean(hasAlpha),
          DBusInt32(bitsPerSample),
          DBusInt32(channels),
          DBusArray(DBusSignature('y'), data.map((d) => DBusByte(d)))
        ]));
  }

  /// This notification should use the image at [path] as the icon.
  factory NotificationHint.imagePath(String path) {
    return NotificationHint('image-path', DBusString(path));
  }

  /// This notification should not be removed when its action is invoked. It will be removed when explicitly removed by this client or the user.
  factory NotificationHint.resident() {
    return NotificationHint('resident', DBusBoolean(true));
  }

  /// This notification should play the sound file at [path] when shown.
  factory NotificationHint.soundFile(String path) {
    return NotificationHint('sound-file', DBusString(path));
  }

  /// This notification should play the sound from the sound theme with [name] when shown.
  factory NotificationHint.soundName(String name) {
    return NotificationHint('sound-name', DBusString(name));
  }

  /// This notification should not trigger any any sounds that would normally play for notifications.
  factory NotificationHint.suppressSound() {
    return NotificationHint('suppress-sound', DBusBoolean(true));
  }

  /// This notification should be transient and by-pass the server's persistent capability.
  factory NotificationHint.transient() {
    return NotificationHint('transient', DBusBoolean(true));
  }

  /// This notification should be placed at the given [x] and [y] co-ordinates.
  factory NotificationHint.location(int x, int y) {
    return NotificationHint(
        '*location', DBusStruct([DBusByte(x), DBusByte(y)]));
  }

  /// This notification should have the given [urgency] level. FIXME enum
  factory NotificationHint.urgency(int urgency) {
    return NotificationHint('urgency', DBusByte(urgency));
  }
}

/// An action the user can perform on a notification.
class NotificationAction {
  /// Unique key for this action.
  final String key;

  /// Label to show to the user.
  final String label;

  /// Creates a new notification action.
  const NotificationAction(this.key, this.label);
}

/// A client that connects to the notifications server.
class NotificationsClient extends DBusRemoteObject {
  /// Creates a new notification client connected to the session D-Bus.
  NotificationsClient(DBusClient sessionBus)
      : super(sessionBus, 'org.freedesktop.Notifications',
            DBusObjectPath('/org/freedesktop/Notifications'));

  /// Sends a notification with a [summary] and optional [body].
  ///
  /// [appName] is a human readable name for the application that generated the notification, e.g. 'Firefox Browser'.
  /// [appIcon] is either a URI (e.g. 'file:///usr/share/icons/firefox.png') or an icon theme name (e.g. 'web-browser').
  /// [expireTimeout] specified the expiration timeout in milliseconds with -1 used for the system default and 0 for no expiration.
  /// [replacesID] is the ID of an existing notification this notification replaces.
  /// [actions] is a list of actions the user can perform on this notification.
  /// [hints] is a list of hints about how the notification should be shown.
  /// [actionCallback] is a function to call when the action on this notification is invoked.
  /// [closedCallback] is a function to call when the action is closed.
  ///
  /// Returns the id of the notification, which can be used in [CloseNotification].
  Future<int> notify(String summary,
      {String body = '',
      String appName = '',
      String appIcon = '',
      int expireTimeoutMs = -1,
      int replacesID = -1,
      List<NotificationHint> hints = const [],
      List<NotificationAction> actions = const [],
      NotificationActionFunction actionCallback,
      NotificationClosedFunction closedCallback}) async {
    var actionsValues = <DBusValue>[];
    for (var action in actions) {
      actionsValues.add(DBusString(action.key));
      actionsValues.add(DBusString(action.label));
    }
    var hintsValues = <DBusValue, DBusValue>{};
    for (var hint in hints) {
      if (hint.key == '*location') {
        hintsValues[DBusString('x')] =
            (hint.value as DBusStruct).children.elementAt(0);
        hintsValues[DBusString('y')] =
            (hint.value as DBusStruct).children.elementAt(1);
      } else {
        hintsValues[DBusString(hint.key)] = hint.value;
      }
    }
    var result = await callMethod('org.freedesktop.Notifications', 'Notify', [
      DBusString(appName),
      DBusUint32(replacesID),
      DBusString(appIcon),
      DBusString(summary),
      DBusString(body),
      DBusArray(DBusSignature('s'), actionsValues),
      DBusDict(DBusSignature('s'), DBusSignature('v'), hintsValues),
      DBusInt32(expireTimeoutMs)
    ]);
    var id = (result.returnValues[0] as DBusUint32).value;
    return id;
  }

  /// Closes an existing notification with the given [id].
  Future closeNotification(int id) async {
    await callMethod(
        'org.freedesktop.Notifications', 'CloseNotification', [DBusUint32(id)]);
  }

  /// Gets the capabilities of the notifications server.
  Future<List<String>> getCapabilities() async {
    var result = await callMethod(
        'org.freedesktop.Notifications', 'GetCapabilities', []);
    var values = result.returnValues;
    if (values.length != 1 || values[0].signature != DBusSignature('as')) {
      throw 'GetCapabilities returned invalid result: ${values}';
    }
    return (values[0] as DBusArray)
        .children
        .map((child) => (child as DBusString).value)
        .toList();
  }

  /// Gets information about the notifications server.
  Future<NotificationServerInformation> getServerInformation() async {
    var result = await callMethod(
        'org.freedesktop.Notifications', 'GetServerInformation', []);
    var values = result.returnValues;
    if (values.length != 4 ||
        values[0].signature != DBusSignature('s') ||
        values[1].signature != DBusSignature('s') ||
        values[2].signature != DBusSignature('s') ||
        values[3].signature != DBusSignature('s')) {
      throw 'GetServerInformation returned invalid result: ${values}';
    }
    return NotificationServerInformation(
        (values[0] as DBusString).value,
        (values[1] as DBusString).value,
        (values[2] as DBusString).value,
        (values[3] as DBusString).value);
  }

  /// Subscribes to org.freedesktop.Notifications.NotificationClosed
  void _subscribeNotificationClosed(
      void Function(int id, int reason) callback) async {
    subscribeSignal('org.freedesktop.Notifications', 'NotificationClosed',
        (values) {
      if (values.length == 2 &&
          values[0].signature == DBusSignature('u') &&
          values[1].signature == DBusSignature('u')) {
        callback(
            (values[0] as DBusUint32).value, (values[1] as DBusUint32).value);
      }
    });
  }

  /// Subscribes to org.freedesktop.Notifications.ActionInvoked
  void _subscribeActionInvoked(
      void Function(int id, String actionKey) callback) async {
    subscribeSignal('org.freedesktop.Notifications', 'ActionInvoked', (values) {
      if (values.length == 2 &&
          values[0].signature == DBusSignature('u') &&
          values[1].signature == DBusSignature('s')) {
        callback(
            (values[0] as DBusUint32).value, (values[1] as DBusString).value);
      }
    });
  }
}
