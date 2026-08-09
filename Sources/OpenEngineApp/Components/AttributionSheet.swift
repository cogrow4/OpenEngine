import SwiftUI
import WallpaperKit

public struct AttributionSheet: View {
    let item: OELibraryItem
    @Binding var presented: Bool

    public init(item: OELibraryItem, presented: Binding<Bool>) {
        self.item = item
        self._presented = presented
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: OE_Theme.Sp.m) {
            HStack {
                Text("Attribution")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { presented = false }
                    .keyboardShortcut(.cancelAction)
            }
            Divider()
            // Hero preview
            AsyncImage(url: item.preview.url) { phase in
                switch phase {
                case .empty:
                    Rectangle().fill(.quaternary).overlay(ProgressView())
                case .success(let img):
                    img.resizable().scaledToFill()
                case .failure:
                    Rectangle().fill(.quaternary).overlay(Image(systemName: "photo").font(.title))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: OE_Theme.R.thumb, style: .continuous))

            VStack(alignment: .leading, spacing: OE_Theme.Sp.s) {
                LabeledContent("Title", value: item.title)
                LabeledContent("Author", value: item.author)
                if let au = item.authorURL, let url = URL(string: au) {
                    HStack {
                        Text("Author URL").foregroundStyle(.secondary)
                        Spacer()
                        Link(url.absoluteString, destination: url)
                            .underline().truncationMode(.middle)
                    }
                }
                HStack {
                    Text("Source").foregroundStyle(.secondary)
                    Spacer()
                    if let url = URL(string: item.sourceURL) {
                        Link(url.absoluteString, destination: url).underline().truncationMode(.middle)
                    }
                }
                LabeledContent("License", value: item.license)
                HStack {
                    Text("Type").foregroundStyle(.secondary)
                    Spacer()
                    Text(item.kind.uppercased())
                }
                if let secs = item.loopDurationSeconds {
                    LabeledContent("Loop length", value: "\(Int(secs)) seconds")
                }
                LabeledContent("Tags", value: item.tags.joined(separator: ", "))
            }

            Spacer()
        }
        .padding(OE_Theme.Sp.l)
        .frame(width: 480, height: 560)
    }
}
