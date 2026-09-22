import SwiftUI

struct ReviewView: View {
    @EnvironmentObject var model: AppModel
    @State private var pending: ReviewItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Review").font(.largeTitle.bold())
                Text("Veronica stops automation instead of guessing when a file needs a human decision.")
                    .foregroundStyle(.secondary)
            }

            if let items = model.snapshot?.unresolvedReviews, !items.isEmpty {
                List(items) { item in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.title).font(.headline)
                            Text(URL(fileURLWithPath: item.relpath).lastPathComponent)
                                .font(.subheadline).textSelection(.enabled)
                            Text(item.explanation)
                                .font(.caption).foregroundStyle(.secondary)
                            Text(ByteCountFormatter.string(fromByteCount: item.sourceSize, countStyle: .file))
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            Button("Show in Finder") { model.revealReview(item) }
                                .buttonStyle(.link)
                            Button("Keep As Is") { pending = item }
                                .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listStyle(.inset)
            } else {
                EmptyStateView(title: "Nothing needs review", systemImage: "checkmark.circle", message: "Every item in the latest plan is either complete, deliberately preserved, or safely skippable.")
            }
        }
        .padding(28)
        .confirmationDialog("Keep this original unchanged?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("Keep As Is") {
                if let item = pending { Task { await model.keepAsIs(item) } }
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            Text("This records a guarded review decision in Veronica's database. The media file itself is not modified, and the decision is only reused while the source identity and review reason still match.")
        }
    }
}
