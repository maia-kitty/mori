//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

ShellRoot {
    NotificationServer {
        id: notificationServer
        actionsSupported: true
        persistenceSupported: true
        onNotification: notification => notification.tracked = true
    }

    Bar {
        notificationServer: notificationServer
    }
}
