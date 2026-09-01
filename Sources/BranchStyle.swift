import AppKit

/// ブランチ名への色の割り当て。
///
/// 色は固定ではなく、一覧に出ているブランチ名から毎回決める。同じブランチ名には必ず同じ色が付き、
/// 違うブランチ名には違う色が付くので、どのリポジトリが同じブランチにいるかが一目で分かる。
///
/// 1 つのリポジトリにしかないブランチには色を付けない。そのブランチに色があっても
/// 比べる相手がおらず、全部に色を付けると意味のない色の羅列になってしまうため。
/// 「色が付いている＝他のリポジトリと同じブランチにいる」という読み方になる。
enum BranchStyle {

    /// メニューに並んでいる順のブランチ名から、ブランチ名 -> 色 を作る。
    /// 戻り値にキーが無いブランチは既定の文字色のまま。
    static func colors(for branchesInOrder: [String]) -> [String: NSColor] {
        var occurrences: [String: Int] = [:]
        for branch in branchesInOrder { occurrences[branch, default: 0] += 1 }

        var assigned: [String: NSColor] = [:]
        for branch in branchesInOrder where (occurrences[branch] ?? 0) > 1 && assigned[branch] == nil {
            assigned[branch] = palette[assigned.count % palette.count]
        }
        return assigned
    }

    /// メニューの明暗どちらでも読める色だけを、隣り合ったときに紛れにくい順に並べてある。
    /// 黄色系は明るい背景で読めないので入れていない。
    private static let palette: [NSColor] = [
        .systemBlue, .systemOrange, .systemGreen, .systemPurple, .systemRed,
        .systemTeal, .systemPink, .systemIndigo, .systemBrown,
    ]
}
