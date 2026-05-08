import Foundation

enum NewFileNotification {
    static let toolbarOrMenuUsed =
        Notification.Name("dev.newfile.NewFile.toolbarOrMenuUsed")
    static let openPreferences =
        Notification.Name("dev.newfile.NewFile.openPreferences")
}
