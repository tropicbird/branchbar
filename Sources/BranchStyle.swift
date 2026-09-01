import AppKit

/// ブランチ名への色の割り当て。
///
/// 色は固定ではなく、一覧に出ているブランチ名から毎回決める。同じブランチ名には必ず同じ色が付き、
/// 違うブランチ名には違う色が付くので、どのリポジトリが同じブランチにいるかが一目で分かる。
///
/// 1 つのリポジトリにしかないブランチにも色を付ける。色を付けないでおくと、
/// 別々のブランチにいる複数のリポジトリが揃って既定色になり、
/// 「同じブランチにいる」ように見えてしまうため。
enum BranchStyle {

    /// メニューに並んでいる順のブランチ名から、ブランチ名 -> 色 を作る。
    /// 先に出てきたブランチから順にパレットを割り当てる。
    static func colors(for branchesInOrder: [String]) -> [String: NSColor] {
        var assigned: [String: NSColor] = [:]
        for branch in branchesInOrder where assigned[branch] == nil {
            assigned[branch] = palette[assigned.count % palette.count]
        }
        return assigned
    }

    /// メニューの明暗どちらでも読める色だけを、隣り合ったときに紛れにくい順に並べてある。
    /// 黄色系は明るい背景で読めないので入れていない。
    /// ブランチの種類がこの数を超えると先頭から巡回するので、そこだけ色が重複しうる。
    private static let palette: [NSColor] = [
        .systemBlue, .systemOrange, .systemGreen, .systemPurple, .systemRed,
        .systemTeal, .systemPink, .systemIndigo, .systemBrown,
    ]
}
