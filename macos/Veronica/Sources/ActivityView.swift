import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Activity").font(.largeTitle.bold())
                    Text(model.isRunningAnnual ? "Live progress from the current maintenance run" : "What Veronica did during the most recent run")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.isRunningAnnual { ProgressView() }
            }

            if model.isRunningAnnual, let progress = model.currentProgress {
                ProgressView(value: progress)
            }

            if !model.events.isEmpty {
                List(model.events) { event in
                    ActivityEventRow(event: event)
                }
                .listStyle(.inset)
            } else if !model.activityLines.isEmpty {
                ScrollView {
                    Text(model.activityLines.joined(separator: "\n"))
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            } else {
                EmptyStateView(title: "No activity yet", systemImage: "waveform.path.ecg", message: "Run maintenance from the Dashboard. Planning, verification, and commits will appear here live.")
            }
        }
        .padding(28)
    }
}

struct ActivityEventRow: View {
    let event: EngineEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconStyle)
                .frame(width: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.title).fontWeight(.medium)
                    if let index = event.index, let total = event.total {
                        Text("\(index)/\(total)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                if let detail = event.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            Spacer()
            if let saving = event.savingPercent, saving != 0 {
                Text("\(saving, specifier: "%.1f")% saved")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(.vertical, 4)
    }

    private var icon: String {
        if event.status == "FAILED" { return "xmark.octagon.fill" }
        if event.status == "KEEP_ORIGINAL" { return "equal.circle.fill" }
        if event.status == "STAGED_VERIFIED" { return "checkmark.seal.fill" }
        if event.event == "commit_item" { return "checkmark.circle.fill" }
        if event.event == "annual_complete" { return "checkmark.circle.fill" }
        if event.event == "plan_complete" { return "doc.text.magnifyingglass" }
        if event.event == "batch_started" || event.event == "staging_started" { return "gearshape.2" }
        return "circle.fill"
    }

    private var iconStyle: Color {
        if event.status == "FAILED" { return .red }
        if event.status == "KEEP_ORIGINAL" { return .secondary }
        if event.status == "STAGED_VERIFIED" || event.event == "commit_item" || event.event == "annual_complete" { return .green }
        return .secondary
    }
}
