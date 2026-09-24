import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("History").font(.largeTitle.bold())
                Text("A visible audit trail of media Veronica actually replaced.")
                    .foregroundStyle(.secondary)
            }

            if let changes = model.snapshot?.recentChanges, !changes.isEmpty {
                Table(changes) {
                    TableColumn("File") { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(URL(fileURLWithPath: item.relpath).lastPathComponent).lineLimit(1)
                            Text(item.operationLabel).font(.caption).foregroundStyle(.secondary)
                            Text(item.root)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    TableColumn("Before") { item in
                        Text(size(item.sourceSize)).monospacedDigit()
                    }
                    .width(min: 80, ideal: 95)
                    TableColumn("After") { item in
                        Text(size(item.outputSize)).monospacedDigit()
                    }
                    .width(min: 80, ideal: 95)
                    TableColumn("Saved") { item in
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(size(item.savingBytes)).monospacedDigit()
                            Text("\(item.savingPercent, specifier: "%.1f")%").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 85, ideal: 100)
                    TableColumn("Date") { item in
                        Text(shortDate(item.completedAt)).foregroundStyle(.secondary)
                    }
                    .width(min: 110, ideal: 130)
                    TableColumn("") { item in
                        Button("Reveal") { model.reveal(item.finalPath) }.buttonStyle(.link)
                    }
                    .width(60)
                }
            } else {
                SectionEmptyStateView(
                    title: "No history",
                    systemImage: "clock.arrow.circlepath",
                    message: "Files only appear here after a verified replacement has been committed."
                )
            }
        }
        .frame(maxWidth: 1180, alignment: .leading)
        .padding(.horizontal, 32)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VeronicaTheme.canvas)
    }

    private func size(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func shortDate(_ value: String?) -> String {
        guard let value else { return "—" }
        return String(value.prefix(10))
    }
}
