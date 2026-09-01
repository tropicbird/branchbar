import AppKit

@main
struct BranchBarApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()   // NSApplication.delegate は weak なので、ここで保持し続ける
        application.delegate = delegate
        application.run()
    }
}
