import AppKit
import SwiftUI

/// 並び替え・追加・削除をまとめて行うウインドウ。
/// メニュー項目を 1 回選ぶたびにメニューが閉じてしまうため、
/// 並び替えはメニュー内ではなくこのウインドウで行う。
@MainActor
final class RepoManagerWindow {

    static let shared = RepoManagerWindow()

    private var window: NSWindow?

    func show(store: RepoStore) {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false   // 閉じても使い回す
            window.center()
            window.setFrameAutosaveName("RepoManagerWindow")
            self.window = window
        }
        updateContent(store: store)

        // メニューバーだけのアプリ（LSUIElement）なので、前面に出すには明示的な activate が要る
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// 開いたままのウインドウを作り直す。言語を切り替えたときに呼ぶ。
    func refresh(store: RepoStore) {
        guard window != nil else { return }
        updateContent(store: store)
    }

    private func updateContent(store: RepoStore) {
        guard let window else { return }
        window.title = L("Repositories", "リポジトリ")
        window.contentView = NSHostingView(rootView: RepoManagerView(store: store))
    }
}

struct RepoManagerView: View {

    @ObservedObject var store: RepoStore
    @State private var selection: Set<String> = []

    /// 「↑」「↓」は選択がちょうど 1 つのときだけ効かせる（複数選択の移動は挙動が読みにくいため）
    private var selectedRepo: Repo? {
        guard selection.count == 1, let id = selection.first else { return nil }
        return store.repos.first { $0.id == id }
    }

    /// メニューと同じ規則で色を決める（同じブランチ名＝同じ色）
    private var branchColors: [String: NSColor] {
        BranchStyle.colors(for: store.repos.compactMap { store.branch(of: $0) })
    }

    var body: some View {
        let colors = branchColors

        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(store.repos) { repo in
                    RepoRow(name: store.displayName(of: repo),
                            path: repo.url.path,
                            group: store.group(of: repo),
                            branch: store.branch(of: repo),
                            color: store.branch(of: repo)
                                .flatMap { colors[$0] }
                                .map(Color.init(nsColor:)))
                        .tag(repo.id)
                }
                .onMove { store.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .overlay {
                if store.repos.isEmpty {
                    Text(L("Add repositories with “＋”", "「＋」でリポジトリを追加"))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button { store.addRepositories() } label: {
                    Image(systemName: "plus")
                }
                .help(L("Add repositories", "リポジトリを追加"))

                Button {
                    store.remove(ids: selection)
                    selection = []
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection.isEmpty)
                .help(L("Remove the selected repositories from the list", "選択したリポジトリを一覧から外す"))

                Button { setGroup() } label: {
                    Image(systemName: "folder")
                }
                .disabled(selection.isEmpty)
                .help(L("Set a group for the selected repositories", "選択したリポジトリのグループを設定"))

                Spacer()

                Text(L("Drag to reorder", "ドラッグして並び替え"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button { move(by: -1) } label: {
                    Image(systemName: "arrow.up")
                }
                .disabled(!canMove(by: -1))
                .help(L("Move up", "上へ移動"))

                Button { move(by: 1) } label: {
                    Image(systemName: "arrow.down")
                }
                .disabled(!canMove(by: 1))
                .help(L("Move down", "下へ移動"))
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 380, minHeight: 220)
    }

    private func setGroup() {
        // 選択が全て同じグループなら、その名前を初期値にする
        let current = Set(store.repos.filter { selection.contains($0.id) }
                                     .map { store.group(of: $0) ?? "" })
        guard let name = GroupPrompt.run(current: current.count == 1 ? current.first : nil,
                                         suggestions: store.groupNames) else { return }
        store.setGroup(name, for: selection)
    }

    private func move(by delta: Int) {
        guard let repo = selectedRepo else { return }
        store.move(repo, by: delta)
    }

    private func canMove(by delta: Int) -> Bool {
        guard let repo = selectedRepo else { return false }
        return store.canMove(repo, by: delta)
    }
}

/// グループ名を入力させる小さなダイアログ。既存のグループはプルダウンから選べる。
enum GroupPrompt {

    /// キャンセルなら nil。空文字が返った場合は「グループなし」を意味する。
    static func run(current: String?, suggestions: [String]) -> String? {
        NSApp.activate(ignoringOtherApps: true)

        let combo = NSComboBox(frame: NSRect(x: 0, y: 0, width: 260, height: 26))
        combo.addItems(withObjectValues: suggestions)
        combo.completes = true
        combo.stringValue = current ?? ""

        let alert = NSAlert()
        alert.messageText = L("Set Group", "グループを設定")
        alert.informativeText = L("""
            Choose an existing group or type a new name.
            Leave it empty to clear the group.
            """,
            """
            既存のグループを選ぶか、新しい名前を入力してください。
            空欄にするとグループなしに戻ります。
            """)
        alert.accessoryView = combo
        alert.addButton(withTitle: L("Set", "設定"))
        alert.addButton(withTitle: L("Cancel", "キャンセル"))
        alert.window.initialFirstResponder = combo

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return combo.stringValue
    }
}

private struct RepoRow: View {

    let name: String
    let path: String
    let group: String?
    let branch: String?
    let color: Color?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                HStack(spacing: 6) {
                    if let group {
                        Text(group)
                            .font(.caption)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.secondary.opacity(0.18)))
                    }
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 12)

            Text(branch ?? L("Not a Git repository", "Git リポジトリではありません"))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(branchStyle)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }

    private var branchStyle: AnyShapeStyle {
        guard branch != nil else { return AnyShapeStyle(.secondary) }
        return color.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary)
    }
}
