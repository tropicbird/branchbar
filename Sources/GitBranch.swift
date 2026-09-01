import Foundation

/// `.git/HEAD` を直接読んで現在のブランチ名を求める。
/// git コマンドを起動しないので速く、メニューを開くたびに呼んでも負荷にならない。
enum GitBranch {

    static func currentBranch(of repoURL: URL) -> String? {
        guard let gitDir = gitDirectory(of: repoURL),
              let raw = try? String(contentsOf: gitDir.appendingPathComponent("HEAD"), encoding: .utf8)
        else { return nil }

        let head = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if head.hasPrefix("ref: ") {
            let ref = String(head.dropFirst(5))
            let heads = "refs/heads/"
            return ref.hasPrefix(heads) ? String(ref.dropFirst(heads.count)) : ref
        }

        // detached HEAD（コミット SHA が直接書かれている）
        guard head.count >= 7 else { return nil }
        return "\(head.prefix(7)) (detached)"
    }

    /// 選んだフォルダ自身か、その親をたどって `.git` を持つディレクトリを探す。
    /// リポジトリ内のサブフォルダを選んでしまってもリポジトリのルートを見つけられる。
    static func repositoryRoot(from directory: URL) -> URL? {
        var current = directory.standardizedFileURL
        while true {
            if gitDirectory(of: current) != nil { return current }
            let parent = current.deletingLastPathComponent().standardizedFileURL
            if parent == current { return nil }   // "/" まで到達
            current = parent
        }
    }

    /// リポジトリの実体の .git ディレクトリ。worktree / submodule では
    /// `.git` がファイルで、中身が `gitdir: <path>` になっている。
    private static func gitDirectory(of repoURL: URL) -> URL? {
        let dotGit = repoURL.appendingPathComponent(".git")
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dotGit.path, isDirectory: &isDirectory) else { return nil }
        if isDirectory.boolValue { return dotGit }

        guard let contents = try? String(contentsOf: dotGit, encoding: .utf8),
              let line = contents.split(separator: "\n").first(where: { $0.hasPrefix("gitdir:") })
        else { return nil }

        let path = line.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return nil }
        return path.hasPrefix("/")
            ? URL(fileURLWithPath: path)
            : repoURL.appendingPathComponent(path).standardizedFileURL
    }
}
