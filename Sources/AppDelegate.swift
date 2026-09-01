import AppKit

/// メニューバーの本体。
///
/// SwiftUI の `MenuBarExtra` ではメニュー項目の文字色指定が無視され、ツールチップも設定できないため、
/// メニューだけは AppKit で組んでいる（`attributedTitle` で色、`toolTip` でホバー表示）。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let store = RepoStore()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "BranchBar")
        icon?.isTemplate = true   // メニューバーの明暗に追従させる
        statusItem.button?.image = icon

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false   // 有効・無効はこちらで決める
        statusItem.menu = menu

        self.statusItem = statusItem
    }

    /// メニューが開く直前に毎回組み直す。ブランチもログイン項目の状態も、ここで最新になる。
    func menuNeedsUpdate(_ menu: NSMenu) {
        store.refreshNow()
        rebuild(menu)
    }

    // MARK: - メニューの構築

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()

        if store.repos.isEmpty {
            menu.addItem(disabledItem(L("No repositories selected", "リポジトリが未選択です")))
        } else {
            // 色は一覧全体を見てから決まるので、ここでまとめて求めて配る
            let colors = BranchStyle.colors(for: store.repos.compactMap { store.branch(of: $0) })
            addRepositoryItems(to: menu, colors: colors)
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(L("Add Repositories…", "リポジトリを追加…"), #selector(addRepositories)))
        menu.addItem(actionItem(L("Reorder / Remove…", "並び替え・削除…"), #selector(openManager)))

        menu.addItem(.separator())
        menu.addItem(terminalItem())
        menu.addItem(languageItem())

        let login = actionItem(L("Open at Login", "ログイン時に起動"), #selector(toggleLoginItem))
        login.state = LoginItem.isEnabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = actionItem(L("Quit", "終了"), #selector(quit))
        quit.keyEquivalent = "q"
        menu.addItem(quit)
    }

    /// グループが変わるところで見出しを挟む（グループなしに戻るところは区切り線）。
    /// 一覧に出ている順そのままなので、管理ウインドウで見えている並びとメニューが一致する。
    private func addRepositoryItems(to menu: NSMenu, colors: [String: NSColor]) {
        var previousGroup: String?
        var isFirst = true

        for repo in store.repos {
            let group = store.group(of: repo)
            if isFirst {
                if let group { menu.addItem(headerItem(group)) }
            } else if group != previousGroup {
                if let group { menu.addItem(headerItem(group)) } else { menu.addItem(.separator()) }
            }

            let item = repositoryItem(for: repo, colors: colors)
            item.indentationLevel = group == nil ? 0 : 1
            menu.addItem(item)

            isFirst = false
            previousGroup = group
        }
    }

    private func headerItem(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) { return NSMenuItem.sectionHeader(title: title) }

        let item = disabledItem(title)
        item.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor
        ])
        return item
    }

    private func repositoryItem(for repo: Repo, colors: [String: NSColor]) -> NSMenuItem {
        let item = actionItem("", #selector(openInTerminal(_:)))
        item.attributedTitle = title(for: repo, colors: colors)
        item.representedObject = repo.url
        item.toolTip = repo.url.path        // ホバーでフルパスを出す
        return item
    }

    /// 「リポジトリ名 — ブランチ」。ブランチ側にだけ色を付ける。
    /// リポジトリ名に色を指定しないのは、ハイライト時に地の色が反転するのに任せるため。
    private func title(for repo: Repo, colors: [String: NSColor]) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)   // attributedTitle は font を指定しないと既定書体になる
        let title = NSMutableAttributedString(
            string: "\(store.displayName(of: repo))  —  ",
            attributes: [.font: font]
        )

        let branch = store.branch(of: repo)
        var attributes: [NSAttributedString.Key: Any] = [.font: font]
        if let color = branch.flatMap({ colors[$0] }) ?? (branch == nil ? NSColor.secondaryLabelColor : nil) {
            attributes[.foregroundColor] = color
        }
        title.append(NSAttributedString(string: branch ?? L("(Not a Git repository)", "（Git リポジトリではありません）"),
                                        attributes: attributes))
        return title
    }

    private func terminalItem() -> NSMenuItem {
        let parent = disabledItem(L("Terminal App: \(TerminalLauncher.applicationName)",
                                   "ターミナルアプリ: \(TerminalLauncher.applicationName)"))
        parent.isEnabled = true

        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for url in TerminalLauncher.availableApplications {
            let item = actionItem(TerminalLauncher.name(of: url), #selector(selectTerminal(_:)))
            item.representedObject = url
            item.state = TerminalLauncher.isSelected(url) ? .on : .off
            item.toolTip = url.path
            submenu.addItem(item)
        }
        submenu.addItem(.separator())
        submenu.addItem(actionItem(L("Other…", "その他…"), #selector(chooseTerminal)))

        parent.submenu = submenu
        return parent
    }

    private func languageItem() -> NSMenuItem {
        let parent = disabledItem(L("Language", "言語"))
        parent.isEnabled = true

        let submenu = NSMenu()
        submenu.autoenablesItems = false
        for language in L10n.Language.allCases {
            let item = actionItem(name(of: language), #selector(selectLanguage(_:)))
            item.representedObject = language.rawValue
            item.state = L10n.selection == language ? .on : .off
            submenu.addItem(item)
        }

        parent.submenu = submenu
        return parent
    }

    /// 言語名はその言語自身で書く（英語は English、日本語は 日本語）のが分かりやすい。
    private func name(of language: L10n.Language) -> String {
        switch language {
        case .system:   return L("Match System", "システムに合わせる")
        case .english:  return "English"
        case .japanese: return "日本語"
        }
    }

    private func actionItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: - 操作

    @objc private func openInTerminal(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        TerminalLauncher.open(Repo(url: url))
    }

    @objc private func addRepositories() { store.addRepositories() }

    @objc private func openManager() { RepoManagerWindow.shared.show(store: store) }

    @objc private func selectTerminal(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        TerminalLauncher.select(url)
    }

    @objc private func chooseTerminal() { TerminalLauncher.chooseApplication() }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let language = L10n.Language(rawValue: raw) else { return }
        L10n.selection = language
        RepoManagerWindow.shared.refresh(store: store)   // 開いていれば中身を作り直す
    }

    @objc private func toggleLoginItem() { LoginItem.setEnabled(!LoginItem.isEnabled) }

    @objc private func quit() { NSApplication.shared.terminate(nil) }
}
