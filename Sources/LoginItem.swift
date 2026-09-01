import AppKit
import ServiceManagement

/// ログイン時の自動起動。状態は SMAppService 側が持っているので、こちらでは保存しない。
/// （メニューを開くたびに `isEnabled` を読み直すので、システム設定側で変えられても表示がずれない）
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        if enabled && !isInstalled && !confirmRegisteringUninstalledApp() { return }

        do {
            if enabled {
                try SMAppService.mainApp.register()
                // ユーザーがシステム設定側で止めている場合はここに来る
                if SMAppService.mainApp.status == .requiresApproval { askForApproval() }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            report(error, enabling: enabled)
        }
    }

    /// アプリケーションフォルダに置かれているか。
    /// ビルドフォルダのまま登録すると、再ビルドでアプリが消えて自動起動が黙って壊れる。
    private static var isInstalled: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/")
            || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    private static func confirmRegisteringUninstalledApp() -> Bool {
        runAlert(
            style: .warning,
            title: L("Registering from outside the Applications folder",
                     "アプリケーションフォルダの外から登録しようとしています"),
            message: L("""
                Current location: \(Bundle.main.bundlePath)

                If you register it while it lives in the build folder, the next rebuild \
                replaces the app and launching at login stops working. Install it to \
                /Applications with ./build.sh --install first.
                """,
                """
                現在の場所: \(Bundle.main.bundlePath)

                ビルドフォルダのまま登録すると、次に再ビルドしたときにアプリが差し替わり、
                自動起動が動かなくなります。先に ./build.sh --install で
                /Applications に入れてから登録することをおすすめします。
                """),
            buttons: [L("Cancel", "やめる"), L("Register Anyway", "このまま登録")]
        ) == .alertSecondButtonReturn
    }

    private static func askForApproval() {
        let response = runAlert(
            style: .informational,
            title: L("Approval required in System Settings", "システム設定での許可が必要です"),
            message: L("Enable BranchBar under “Login Items & Extensions”.",
                       "「ログイン項目と機能拡張」で BranchBar を有効にしてください。"),
            buttons: [L("Open System Settings", "システム設定を開く"), L("Later", "後で")]
        )
        if response == .alertFirstButtonReturn { SMAppService.openSystemSettingsLoginItems() }
    }

    private static func report(_ error: Error, enabling: Bool) {
        _ = runAlert(
            style: .warning,
            title: enabling
                ? L("Could not register for launch at login", "自動起動を登録できませんでした")
                : L("Could not unregister from launch at login", "自動起動を解除できませんでした"),
            message: """
                \(error.localizedDescription)

                \(L("You can set this manually in System Settings → General → Login Items & Extensions.",
                     "システム設定の「一般」→「ログイン項目と機能拡張」から手動で設定できます。"))
                """,
            buttons: ["OK"]
        )
    }

    @discardableResult
    private static func runAlert(style: NSAlert.Style,
                                 title: String,
                                 message: String,
                                 buttons: [String]) -> NSApplication.ModalResponse {
        // メニューバーだけのアプリなので、前面に出すには明示的な activate が要る
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = style
        alert.messageText = title
        alert.informativeText = message
        for button in buttons { alert.addButton(withTitle: button) }
        return alert.runModal()
    }
}
