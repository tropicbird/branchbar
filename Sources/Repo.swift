import Foundation

/// 選択されたローカルリポジトリ
struct Repo: Identifiable, Hashable {
    let url: URL
    var id: String { url.path }
    /// フォルダ名。一覧の中で重複しうるので、表示には `displayNames(in:)` の結果を使う。
    var name: String { url.lastPathComponent }
}

extension Repo {

    /// 一覧の中で名前がぶつかるものだけ、区別できるところまで親フォルダを足した表示名を作る。
    ///
    /// 例: `/dev/home-server` と `/dev/shadowinggo-flutter-refactor/home-server` を
    /// 両方登録すると、`dev/home-server` と `shadowinggo-flutter-refactor/home-server` になる。
    /// ぶつかっていないリポジトリはフォルダ名のまま短く保つ。
    static func displayNames(in repos: [Repo]) -> [String: String] {
        /// 表示に使う末尾のパス要素数
        var depths = Dictionary(uniqueKeysWithValues: repos.map { ($0.id, 1) })

        // 衝突しているものだけ親フォルダを 1 つずつ足していく。
        // 親をたどり切ったものはそれ以上伸ばせないので、そこで打ち止めになる。
        while true {
            let labels = repos.map { label(for: $0, depth: depths[$0.id] ?? 1) }
            var occurrences: [String: Int] = [:]
            for label in labels { occurrences[label, default: 0] += 1 }

            var extended = false
            for (index, repo) in repos.enumerated() where (occurrences[labels[index]] ?? 0) > 1 {
                let depth = depths[repo.id] ?? 1
                guard depth < components(of: repo).count else { continue }   // これ以上さかのぼれない
                depths[repo.id] = depth + 1
                extended = true
            }
            if !extended { break }
        }

        return Dictionary(uniqueKeysWithValues: repos.map { ($0.id, label(for: $0, depth: depths[$0.id] ?? 1)) })
    }

    private static func components(of repo: Repo) -> [String] {
        repo.url.pathComponents.filter { $0 != "/" }
    }

    private static func label(for repo: Repo, depth: Int) -> String {
        let parts = components(of: repo)
        guard !parts.isEmpty else { return repo.url.path }
        return parts.suffix(max(depth, 1)).joined(separator: "/")
    }
}
