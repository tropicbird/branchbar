import Foundation

/// 表示言語。文字列が数十しかないので `.lproj` / `Localizable.strings` は使わず、
/// 呼び出し側に英語と日本語を並べて書く。表示中に切り替えてもすぐ反映される
/// （メニューは開くたびに組み直され、管理ウインドウは中身を作り直すため）。
enum L10n {

    enum Language: String, CaseIterable {
        case system                 // macOS の言語設定に従う
        case english = "en"
        case japanese = "ja"
    }

    private static let defaultsKey = "language"

    /// メニューで選ばれている設定。既定はシステムに従う。
    static var selection: Language {
        get {
            guard let raw = UserDefaults.standard.string(forKey: defaultsKey) else { return .system }
            return Language(rawValue: raw) ?? .system
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }

    /// 実際に表示に使う言語。`.system` のときは macOS の優先言語から決める
    /// （日本語が最優先なら日本語、それ以外は英語）。
    static var current: Language {
        guard selection == .system else { return selection }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("ja") ? .japanese : .english
    }
}

/// 英語と日本語を並べて書き、表示言語に応じてどちらかを返す。
/// 言語を増やす場合はここと `L10n.Language` に足す。
func L(_ english: String, _ japanese: String) -> String {
    L10n.current == .japanese ? japanese : english
}
