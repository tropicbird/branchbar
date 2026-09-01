import AppKit
import Combine
import Foundation

/// 選択されたリポジトリの一覧（表示順そのもの）と、それぞれの現在のブランチを保持する。
final class RepoStore: ObservableObject {

    /// メニューと管理ウインドウに出す順番。この配列の順序がそのまま表示順になる。
    @Published private(set) var repos: [Repo] = [] {
        didSet {
            displayNames = Repo.displayNames(in: repos)
            save()
        }
    }

    /// repo.id -> 表示名。フォルダ名が重複するときだけ親フォルダが付く。
    @Published private(set) var displayNames: [String: String] = [:]

    /// repo.id -> ブランチ名。キーが無い場合は Git リポジトリとして読めなかったことを示す。
    /// 順序と切り離して持っているので、並び替えてもブランチを読み直す必要がない。
    @Published private(set) var branches: [String: String] = [:]

    /// repo.id -> グループ名。キーが無い＝グループなし。
    @Published private(set) var groups: [String: String] = [:]

    private let defaultsKey = "repositoryPaths"
    private let groupsKey = "repositoryGroups"
    private let queue = DispatchQueue(label: "BranchBar.refresh", qos: .utility)
    private var timer: Timer?

    init() {
        let paths = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        groups = UserDefaults.standard.dictionary(forKey: groupsKey) as? [String: String] ?? [:]
        // init 内の代入では didSet が走らないので、派生する値はここで作る
        repos = paths.map { Repo(url: URL(fileURLWithPath: $0)) }
        displayNames = Repo.displayNames(in: repos)
        branches = Self.readBranches(of: repos)   // 起動直後だけ同期で読み、初回表示の空振りを避ける

        // ブランチを切り替えたあともメニューが古いままにならないように定期更新する。
        // 読むのは小さなファイルだけなので負荷は無視できる。
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func branch(of repo: Repo) -> String? { branches[repo.id] }

    func displayName(of repo: Repo) -> String { displayNames[repo.id] ?? repo.name }

    func group(of repo: Repo) -> String? { groups[repo.id] }

    /// 一覧に出てくる順のグループ名（重複なし）。グループ指定の候補として使う。
    var groupNames: [String] {
        var seen: Set<String> = []
        return repos.compactMap { groups[$0.id] }.filter { seen.insert($0).inserted }
    }

    // MARK: - 更新

    /// メニューを開く直前に呼ぶ同期版。読むのは小さなファイルだけなので待たせない。
    func refreshNow() {
        branches = Self.readBranches(of: repos)
    }

    func refresh() {
        let snapshot = repos
        queue.async { [weak self] in
            let result = Self.readBranches(of: snapshot)
            DispatchQueue.main.async { self?.branches = result }
        }
    }

    private static func readBranches(of repos: [Repo]) -> [String: String] {
        var result: [String: String] = [:]
        for repo in repos {
            if let branch = GitBranch.currentBranch(of: repo.url) { result[repo.id] = branch }
        }
        return result
    }

    // MARK: - リポジトリの選択

    /// フォルダ選択パネルを開き、選ばれたリポジトリを一覧の末尾に追加する。
    func addRepositories() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = L("Select Repositories", "リポジトリを選択")
        panel.message = L("Choose the local repository folders to watch (multiple selection is allowed)",
                          "監視したいローカルリポジトリのフォルダを選んでください（複数選択できます）")
        panel.prompt = L("Add", "追加")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.showsHiddenFiles = false

        guard panel.runModal() == .OK else { return }

        var updated = repos
        for url in panel.urls {
            // リポジトリ内のサブフォルダを選んだ場合はルートに読み替える
            let root = GitBranch.repositoryRoot(from: url) ?? url.standardizedFileURL
            let repo = Repo(url: root)
            if !updated.contains(repo) { updated.append(repo) }
        }
        repos = updated
        regroup()
        refresh()
    }

    func remove(_ repo: Repo) {
        remove(ids: [repo.id])
    }

    func remove(ids: Set<String>) {
        repos.removeAll { ids.contains($0.id) }
        for id in ids { groups.removeValue(forKey: id) }
        saveGroups()
    }

    // MARK: - グループ

    /// 選択したリポジトリのグループを設定する。`nil` または空文字でグループなしに戻す。
    func setGroup(_ name: String?, for ids: Set<String>) {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        for id in ids {
            if trimmed.isEmpty { groups.removeValue(forKey: id) } else { groups[id] = trimmed }
        }
        regroup()
        saveGroups()
    }

    /// 同じグループのリポジトリが離れ離れにならないよう、隣り合うように詰める。
    ///
    /// グループの塊は「最初のメンバーが今いる位置」に置き、グループに属さないリポジトリは
    /// その場から動かさない。こうしておくと、グループを設定したリポジトリが一覧の遠くへ
    /// 飛んでいかず、並びの見え方がほとんど変わらない。
    private func regroup() {
        var result: [Repo] = []
        var placed: Set<String> = []

        for repo in repos {
            guard let group = groups[repo.id] else {
                result.append(repo)                 // グループなしはその場に留める
                continue
            }
            guard placed.insert(group).inserted else { continue }   // その塊は既に置いた
            result.append(contentsOf: repos.filter { groups[$0.id] == group })
        }
        repos = result
    }

    // MARK: - 並び替え

    /// リスト上のドラッグによる並び替え。
    /// `destination` は「移動前の配列で、この位置の手前に挿入する」という SwiftUI の
    /// `onMove` の流儀に合わせている。
    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { repos[$0] }

        var remaining = repos
        for index in source.sorted(by: >) { remaining.remove(at: index) }

        // 挿入位置より手前から抜いた分だけ、挿入位置が前にずれる
        let removedBefore = source.count(in: 0..<max(destination, 0))
        let insertionIndex = min(max(destination - removedBefore, 0), remaining.count)
        remaining.insert(contentsOf: moving, at: insertionIndex)

        repos = remaining
    }

    /// 「↑」「↓」ボタンによる 1 段ずつの移動。端にいる場合は何もしない。
    func move(_ repo: Repo, by delta: Int) {
        guard let index = repos.firstIndex(of: repo) else { return }
        let target = index + delta
        guard repos.indices.contains(target) else { return }
        repos.swapAt(index, target)
    }

    func canMove(_ repo: Repo, by delta: Int) -> Bool {
        guard let index = repos.firstIndex(of: repo) else { return false }
        return repos.indices.contains(index + delta)
    }

    private func save() {
        UserDefaults.standard.set(repos.map(\.url.path), forKey: defaultsKey)
    }

    private func saveGroups() {
        UserDefaults.standard.set(groups, forKey: groupsKey)
    }
}
