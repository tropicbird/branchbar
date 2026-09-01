import AppKit
import UniformTypeIdentifiers

/// メニューの行をクリックしたときに、そのリポジトリをターミナルで開く。
/// 開くアプリは選べる。未設定なら macOS 標準の Terminal.app を使う。
///
/// tmux / cmux のような CLI の多重化ツールはアプリではなくコマンドなので、ここでは扱わない。
/// それらを使う場合は、選んだターミナル側（シェルの rc など）で起動する。
enum TerminalLauncher {

    private static let defaultsKey = "terminalApplicationPath"

    /// 現在選ばれているターミナル。設定が無い、または指定先が消えている場合は Terminal.app に戻す。
    static var applicationURL: URL? {
        if let path = UserDefaults.standard.string(forKey: defaultsKey),
           FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal")
    }

    static var applicationName: String {
        guard let url = applicationURL else { return "Terminal" }
        return name(of: url)
    }

    static func name(of url: URL) -> String {
        FileManager.default.displayName(atPath: url.path)
    }

    static func isSelected(_ url: URL) -> Bool {
        // URL 同士の比較はディレクトリの末尾スラッシュで食い違うのでパスで比べる
        url.path == applicationURL?.path
    }

    static func select(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: defaultsKey)
    }

    /// メニューに並べるターミナルの候補。よくある場所を stat するだけなので毎回呼んでも安い。
    /// Terminal.app は /Applications ではなく /System/Applications/Utilities にあるため、
    /// ファイル選択パネルからは辿り着きにくい。ここに並べておく。
    static var availableApplications: [URL] {
        let directories = ["/System/Applications/Utilities",
                           "/Applications",
                           NSHomeDirectory() + "/Applications"]
        let names = ["Terminal", "iTerm", "cmux", "Warp", "Ghostty",
                     "kitty", "Alacritty", "WezTerm", "Hyper", "Tabby"]

        var found: [URL] = []
        for directory in directories {
            for name in names {
                let url = URL(fileURLWithPath: "\(directory)/\(name).app")
                if FileManager.default.fileExists(atPath: url.path) { found.append(url) }
            }
        }

        // 「その他…」で選んだ変わり種にもチェックが付くように、候補に無ければ加える
        if let current = applicationURL, !found.contains(where: { $0.path == current.path }) {
            found.append(current)
        }
        return found
    }

    // MARK: - 開く

    static func open(_ repo: Repo) {
        guard FileManager.default.fileExists(atPath: repo.url.path) else {
            alert(title: L("Folder not found", "フォルダが見つかりません"), message: repo.url.path)
            return
        }
        guard let application = applicationURL else {
            alert(title: L("No terminal application found", "ターミナルアプリが見つかりません"),
                  message: L("Pick one from “Terminal App: …” in the menu.",
                             "「ターミナルアプリ: …」から使用するアプリを選んでください。"))
            return
        }

        NSWorkspace.shared.open([repo.url],
                                withApplicationAt: application,
                                configuration: NSWorkspace.OpenConfiguration()) { _, error in
            guard let error else { return }
            DispatchQueue.main.async {
                alert(title: L("Could not open with \(applicationName)", "\(applicationName) で開けませんでした"),
                      message: """
                          \(error.localizedDescription)

                          \(L("Some terminals cannot open a folder. Choose a different app in that case.",
                               "フォルダを開けないターミナルもあります。その場合は別のアプリを選んでください。"))
                          """)
            }
        }
    }

    // MARK: - ターミナルアプリの選択

    static func chooseApplication() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = L("Select Terminal Application", "ターミナルアプリを選択")
        panel.message = L("Choose the application used to open repositories",
                          "リポジトリを開くのに使うアプリを選んでください")
        panel.prompt = L("Use", "使用する")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        select(url)
    }

    private static func alert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
