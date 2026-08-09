import SwiftUI
import WallpaperKit

@main
struct OpenEngineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var engine = OEEngine()

    var body: some Scene {
        // Primary window
        WindowGroup {
            RootView()
                .environmentObject(engine)
                .frame(minWidth: 900, minHeight: 560)
                .onAppear { engine.restoreOnLaunch() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1200, height: 760)
        .commands { CommandGroup(replacing: .appInfo) { Button("About OpenEngine") { delegate.showAbout() } } }

        // Settings scene
        Settings {
            SettingsView()
                .environmentObject(engine)
                .frame(minWidth: 520, minHeight: 460)
        }

        MenuBarExtra {
            MenuBarContent(engine: engine)
        } label: {
            Image(systemName: "circle.hexagonpath.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

struct RootView: View {
    @EnvironmentObject var engine: OEEngine
    @State private var selectedTab: SidebarTab = .browse

    enum SidebarTab: String, CaseIterable, Identifiable {
        case browse = "Browse"
        case wallpaper = "Wallpaper"
        case lock = "Lock Screen"
        case settings = "Settings"
        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .browse: return "square.grid.2x2"
            case .wallpaper: return "rectangle.dashed.badge.record"
            case .lock: return "lock.rectangle"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("OpenEngine") {
                    ForEach(SidebarTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            switch selectedTab {
            case .browse: GalleryView()
            case .wallpaper:
                WallpaperTabPage(title: "Wallpaper")
                    .environmentObject(engine)
            case .lock:
                WallpaperTabPage(title: "Lock Screen", scope: .lockScreen)
                    .environmentObject(engine)
            case .settings:
                SettingsView().environmentObject(engine)
            }
        }
        .sheet(item: $engine.attributionSheet) { item in
            AttributionSheet(item: item, presented: Binding(
                get: { engine.attributionSheet != nil },
                set: { if !$0 { engine.attributionSheet = nil } }))
        }
        .alert("OpenEngine", isPresented: alertShown, actions: {
            Button("OK") { }
        }, message: {
            if case .error(let msg) = engine.phase { Text(msg) } else { Text("") }
        })
    }

    private var alertShown: Binding<Bool> {
        Binding(get: {
            if case .error = engine.phase { return true }
            return false
        }, set: { if !$0 { engine.phase = .idle } })
    }
}

struct WallpaperTabPage: View {
    @EnvironmentObject var engine: OEEngine
    let title: String
    var scope: WallpaperController.Scope = .wallpaper

    /// The settings ID for whichever scope this tab represents.
    private var currentID: String? {
        scope == .lockScreen ? engine.settings.lockID : engine.settings.wallpaperID
    }

    var body: some View {
        ScrollView {
            VStack(spacing: OE_Theme.Sp.l) {
                Header(title: title, scope: scope)

                // Download progress
                if engine.downloadProgress > 0 && engine.downloadProgress < 1 {
                    ProgressView(value: engine.downloadProgress)
                        .progressViewStyle(.linear)
                        .padding(.horizontal, OE_Theme.Sp.l)
                        .padding(.vertical, OE_Theme.Sp.xs)
                }

                // Library subsection: all downloaded (cached) items with delete + current-applied indicator.
                let cached = engine.gallery.filter { engine.isCached($0) }
                if !cached.isEmpty {
                    VStack(alignment: .leading, spacing: OE_Theme.Sp.s) {
                        Text("Library")
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, OE_Theme.Sp.l)
                            .padding(.vertical, OE_Theme.Sp.xs)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: OE_Theme.R.card, style: .continuous))
                            .padding(.horizontal, OE_Theme.Sp.l)
                            .padding(.top, OE_Theme.Sp.xs)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240, maximum: 360), spacing: OE_Theme.Sp.m)],
                                  spacing: OE_Theme.Sp.m) {
                            ForEach(cached) { item in tile(item) }
                        }
                    }
                    .padding(.horizontal, OE_Theme.Sp.l)
                }

                // Buffer: pronounced visual separator between Library and Browse All.
                if !cached.isEmpty && !engine.filteredGallery.isEmpty {
                    VStack(spacing: OE_Theme.Sp.l) {
                        Divider()
                            .padding(.horizontal, OE_Theme.Sp.l)
                        Text("Browse All")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, OE_Theme.Sp.xl)
                }

                // Full gallery
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240, maximum: 360), spacing: OE_Theme.Sp.m)],
                          spacing: OE_Theme.Sp.m) {
                    ForEach(engine.filteredGallery) { item in tile(item) }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
    }

    private func tile(_ item: GalleryPresentable) -> some View {
        Button {
            Task { await engine.previewItem(item, as: scope) }
        } label: {
            PreviewTile(presentable: item, isCurrent: item.id == currentID)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if engine.isCached(item) {
                Button("Delete local copy") {
                    engine.deleteLocalCopy(of: item)
                }
                Divider()
            }
            Button("Show attribution") {
                if let it = engine.resolve(itemID: item.id) { engine.attributionSheet = it }
            }
            Divider()
            Button("Apply (current target)") { Task { await engine.previewItem(item, as: scope) } }
            Button("Apply to Wallpaper") { Task { await engine.previewItem(item, as: .wallpaper) } }
            Button("Apply to Lock Screen") { Task { await engine.previewItem(item, as: .lockScreen) } }
            Button("Apply to Both") { Task { await engine.previewItem(item, as: .both) } }
        }
    }

    struct Header: View {
        let title: String
        let scope: WallpaperController.Scope
        var body: some View {
            VStack(alignment: .leading, spacing: OE_Theme.Sp.xs) {
                Text(title).font(.largeTitle.weight(.bold))
                Text("Pick a video loop or image for your \(scope == .lockScreen ? "lock screen" : "desktop wallpaper").")
                    .font(.callout).foregroundStyle(.secondary)
                if scope == .lockScreen {
                    Text("Note: macOS does not let sandboxed apps set the real lock screen (it is owned by loginwindow). OpenEngine shows a best-effort preview at the desktop window level; for the actual lock-screen background, use System Settings → Wallpaper → Lock Screen. Static images may also be set via the system wallpaper picker on macOS 26+.")
                }
            }
            .padding(.horizontal, OE_Theme.Sp.l)
            .padding(.vertical, OE_Theme.Sp.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
