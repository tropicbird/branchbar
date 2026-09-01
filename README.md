# BranchBar

A macOS menu bar app that shows the current branch of the local repositories you choose. That is all it does.

Click the branch icon (`⎇`) in the menu bar to see your repositories with their current branches. Click a row to open that repository in a terminal.

```
infra-tools      —  develop            ← repositories on the same branch share a color
─ Frontend ──────────────────────
   web-app       —  feature/login       ← groups get a header and indentation
   design-system —  feature/login
──────────────────────────────────
Add Repositories…
Reorder / Remove…
──────────────────────────────────
Terminal App: Terminal            ▸
Language                          ▸
✓ Open at Login
──────────────────────────────────
Quit
```

The interface is available in **English and Japanese**. It follows your macOS language setting by default, and **Language** in the menu lets you override it — the change applies immediately, no restart.

## Requirements

macOS 13 or later, and the Xcode Command Line Tools (`swiftc`). No Xcode project — a shell script builds the `.app` bundle directly.

## Build and install

```bash
./build.sh --install
```

This installs to `/Applications/BranchBar.app` and launches it. Without `--install` the script only produces `build/BranchBar.app`.

There is no prebuilt binary. The app is ad-hoc signed (`codesign --sign -`) and not notarized, so build it yourself.

To start it automatically, use **Open at Login** in the menu. Install to `/Applications` **first** — registering the app while it still lives in `build/` breaks auto-launch on the next rebuild, and the app warns you when you try.

## Usage

- **Add repositories** — a folder picker opens; multiple selection is supported. Picking a subfolder of a repository resolves to the repository root.
- **Click a repository row** — opens that folder in a terminal, in a new window at the repository root.
- **Hover a row** — the full path appears as a tooltip.
- **Language** — `Match System` (default), `English` or `日本語`. `Match System` picks Japanese when Japanese is your top preferred language in macOS, and English otherwise. The choice is saved.
- **Terminal app** — a submenu lists the terminals found on this Mac, so you can just pick one. Anything not listed can be chosen from the file picker under **Other…**, and it joins the list afterwards.
  It defaults to `Terminal.app`, and falls back to it if the chosen app has been deleted. Candidates are looked up in `/System/Applications/Utilities`, `/Applications` and `~/Applications`.
  `Terminal.app` lives in `/System/Applications/Utilities`, not `/Applications`, which is exactly why the list exists — a plain file picker barely reaches it.
  CLI multiplexers such as tmux are commands rather than applications, so they cannot be selected here. Start them from the terminal you pick (for example in your shell rc).
- **Reorder / remove** — opens the management window.
  - **Drag** rows to change the order shown in the menu. Multiple rows can be moved at once.
  - Select a row and use **↑ / ↓** to move it one step (enabled for a single selection).
  - **＋** adds, **−** removes the selected repositories from the list (the folders themselves are untouched).
  - **📁** assigns a group name to the selection. Existing groups are offered in a dropdown; an empty value clears the group.
- **Groups** — repositories in the same group are pulled together so they sit next to each other. The block is placed where its first member already is, so assigning a group barely disturbs the order you set up. In the menu each group gets a header and its rows are indented.
- Repositories whose folder names collide (say `dev/home-server` and `dev/refactor/home-server`) get just enough of the parent path added to tell them apart. Everything else keeps the short folder name.
- The list, its order, the groups and the terminal choice are stored in `UserDefaults` (`io.github.tropicbird.branchbar`) and survive restarts.

## Branch colors

Colors are not tied to particular branch names. They are assigned from the branches currently on display, so **repositories sitting on the same branch get the same color** and different branches get different colors — you can tell at a glance which repositories are in sync.

```
web-app         —  feature/checkout    ← blue
api-server      —  feature/checkout    ← blue, same branch
mobile-app      —  main                ← orange
design-system   —  main                ← orange
infra-tools     —  chore/bump-deps     ← default color, nothing to compare with
```

A branch that only one repository is on stays in the default menu color: a color there would have nothing to pair with, and coloring everything turns into a meaningless rainbow. So **colored means "another repository is on this branch too."**

The assignment is deterministic — the same set of branches always produces the same colors, so nothing flickers between openings. The palette holds nine colors that stay readable in both light and dark menus (no yellows); beyond nine shared branches it wraps around. Edit `palette` in `Sources/BranchStyle.swift` to change them.

## How it works

Branch names come from reading `.git/HEAD` directly rather than shelling out to `git`, so there is no process to spawn. The file is re-read right before the menu opens, which keeps the display exact.

- Ordinary branch → `develop`
- Detached HEAD → `68eac1d (detached)`
- Worktrees and submodules (where `.git` is a file) → resolved through the `gitdir:` pointer
- Not a Git repository → `(Not a Git repository)`

Localization is a small table in `Sources/L10n.swift` rather than `.lproj` bundles: with a few dozen strings, writing both languages at the call site (`L("Quit", "終了")`) keeps them visible together and lets the language change take effect without relaunching. To add a language, extend `L10n.Language` and `L(_:_:)`.

The menu is built with AppKit (`NSStatusItem` + `NSMenu`) rather than SwiftUI's `MenuBarExtra`: SwiftUI menu items ignore text color and offer no way to set a tooltip. The management window is SwiftUI hosted in an `NSHostingView`.

## Layout

| File | Role |
| --- | --- |
| `Sources/BranchBarApp.swift` | Entry point |
| `Sources/AppDelegate.swift` | Status item and menu construction |
| `Sources/Repo.swift` | Repository model and collision-free display names |
| `Sources/GitBranch.swift` | Reading `.git/HEAD` and finding the repository root |
| `Sources/RepoStore.swift` | Persistence, add/remove, ordering, grouping, refresh |
| `Sources/BranchStyle.swift` | Branch name to color |
| `Sources/L10n.swift` | English / Japanese strings and language selection |
| `Sources/LoginItem.swift` | Launch at login via `SMAppService` |
| `Sources/TerminalLauncher.swift` | Opening a repository in a terminal, and choosing which one |
| `Sources/RepoManagerWindow.swift` | The reorder / group / remove window |
| `build.sh` | Builds the `.app` bundle with `swiftc` |

## License

MIT — see [LICENSE](LICENSE).
