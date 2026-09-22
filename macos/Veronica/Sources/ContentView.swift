import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case activity = "Activity"
    case review = "Review"
    case history = "History"
    case settings = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .activity: return "waveform.path.ecg"
        case .review: return "exclamationmark.bubble"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var selection: SidebarItem? = .dashboard

    var body: some View {
        Group {
            if model.isLoading && model.snapshot == nil {
                ProgressView("Starting Veronica…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let snapshot = model.snapshot, !snapshot.configured {
                SetupView()
            } else {
                mainInterface
            }
        }
        .overlay(alignment: .bottom) {
            if let error = model.errorMessage {
                HStack(spacing: 9) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                    Spacer()
                    Button("Dismiss") { model.errorMessage = nil }
                        .buttonStyle(.link)
                }
                .font(.callout)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 6, y: 2)
                .padding()
            }
        }
    }

    private var mainInterface: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                HStack {
                    Label(item.rawValue, systemImage: item.icon)
                    Spacer()
                    if item == .review, let count = model.snapshot?.unresolvedReviews.count, count > 0 {
                        Text(count.formatted())
                            .font(.caption.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                .tag(item)
            }
            .navigationTitle("Veronica")
        } detail: {
            switch selection ?? .dashboard {
            case .dashboard: DashboardView()
            case .activity: ActivityView()
            case .review: ReviewView()
            case .history: HistoryView()
            case .settings: SettingsView()
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage).font(.system(size: 40)).foregroundStyle(.secondary)
            Text(title).font(.title2.bold())
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
