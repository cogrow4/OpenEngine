import SwiftUI
import WallpaperKit

/// A scrollable SwiftUI grid of preview tiles with a leading filter bar.
public struct GalleryView: View {
    @EnvironmentObject var engine: OEEngine
    @State private var scope: WallpaperController.Scope = .wallpaper

    var cols: [GridItem] {
        [GridItem(.adaptive(minimum: 240, maximum: 360), spacing: OE_Theme.Sp.m)]
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            if engine.downloadProgress > 0 && engine.downloadProgress < 1 {
                ProgressView(value: engine.downloadProgress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, OE_Theme.Sp.l)
                    .padding(.vertical, OE_Theme.Sp.xs)
            }
            Divider()
            ScrollView {
                if engine.phase == .loading && engine.gallery.isEmpty {
                    loadingState
                } else if case .error(let msg) = engine.phase, engine.gallery.isEmpty {
                    errorState(msg)
                } else {
                    LazyVGrid(columns: cols, spacing: OE_Theme.Sp.m) {
                        ForEach(engine.filteredGallery) { item in tile(item) }
                    }
                    .padding(OE_Theme.Sp.l)
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var loadingState: some View {
        VStack(spacing: OE_Theme.Sp.m) {
            ProgressView().controlSize(.large)
            Text("Loading library…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(OE_Theme.Sp.xxl)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: OE_Theme.Sp.m) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 36)).foregroundStyle(.orange)
            Text("Couldn't reach the library").font(.headline)
            Text(msg).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Retry") { Task { await engine.refresh() } }
        }
        .padding(OE_Theme.Sp.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toolbar: some View {
        HStack(spacing: OE_Theme.Sp.m) {
            FilterPill(title: "All", active: engine.activeKind == nil) { engine.activeKind = nil }
            FilterPill(title: "Images", active: engine.activeKind == .image) { engine.activeKind = .image }
            FilterPill(title: "Video", active: engine.activeKind == .video) { engine.activeKind = .video }

            Spacer()

            HStack(spacing: OE_Theme.Sp.xs) {
                Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                TextField("Search", text: $engine.search)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 260)
                if !engine.search.isEmpty {
                    Button { engine.search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, OE_Theme.Sp.s).padding(.vertical, 6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: OE_Theme.R.pill, style: .continuous))

            Picker("Apply to", selection: $scope) {
                ForEach(WallpaperController.Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 160)

            Button { Task { await engine.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                .help("Refresh library")
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, OE_Theme.Sp.l)
        .padding(.vertical, OE_Theme.Sp.s)
        .background(.regularMaterial)
    }

    private var currentID: String? {
        switch scope {
        case .wallpaper: return engine.settings.wallpaperID
        case .lockScreen: return engine.settings.lockID
        case .both: return engine.settings.wallpaperID ?? engine.settings.lockID
        }
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
}

struct FilterPill: View {
    let title: String
    let active: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.callout.weight(.medium))
                .padding(.horizontal, OE_Theme.Sp.l).padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(active ? AnyShapeStyle(.tint) : AnyShapeStyle(.regularMaterial),
                    in: RoundedRectangle(cornerRadius: OE_Theme.R.pill, style: .continuous))
        .foregroundStyle(active ? Color.white : .primary)
    }
}
