import SwiftUI

enum VeronicaTheme {
    // Brand palette:
    // 60% white / 30% black structure / 10% Indigo Bloom
    static let canvas = Color.white
    static let ink = Color.black
    static let accent = Color(
        red: 129.0 / 255.0,
        green: 60.0 / 255.0,
        blue: 176.0 / 255.0
    )

    static let subtleFill = Color.black.opacity(0.035)
    static let strongerFill = Color.black.opacity(0.055)
    static let border = Color.black.opacity(0.075)
    static let secondaryInk = Color.black.opacity(0.58)
    static let tertiaryInk = Color.black.opacity(0.38)
    static let accentFill = accent.opacity(0.085)
}

struct VeronicaGroupBoxStyle: GroupBoxStyle {
    let fill: Color

    init(fill: Color = VeronicaTheme.subtleFill) {
        self.fill = fill
    }

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            configuration.label
                .font(.headline)
                .foregroundStyle(VeronicaTheme.ink)

            configuration.content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            fill,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(VeronicaTheme.border, lineWidth: 1)
        }
    }
}

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
    @State private var selection: SidebarItem?

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        var initialSelection: SidebarItem = .dashboard

        if let index = arguments.firstIndex(of: "--ui-section"),
           arguments.indices.contains(index + 1) {
            let requested = arguments[index + 1].lowercased()

            if let section = SidebarItem.allCases.first(
                where: { $0.rawValue.lowercased() == requested }
            ) {
                initialSelection = section
            }
        }

        _selection = State(initialValue: initialSelection)
    }


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
        .tint(VeronicaTheme.accent)
        .foregroundStyle(VeronicaTheme.ink)
        .background(VeronicaTheme.canvas)
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
            List(SidebarItem.allCases) { item in
                Button {
                    selection = item
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .frame(width: 18)

                        Text(item.rawValue)
                            .fontWeight(selection == item ? .semibold : .regular)

                        Spacer()

                        if item == .review,
                           let count = model.snapshot?.unresolvedReviews.count,
                           count > 0 {
                            Text(count.formatted())
                                .font(.caption.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(
                                    selection == item
                                        ? VeronicaTheme.accent.opacity(0.14)
                                        : VeronicaTheme.strongerFill,
                                    in: Capsule()
                                )
                        }
                    }
                    .foregroundStyle(
                        selection == item
                            ? VeronicaTheme.accent
                            : VeronicaTheme.ink
                    )
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                    .background(
                        selection == item
                            ? VeronicaTheme.accent.opacity(0.11)
                            : Color.clear,
                        in: RoundedRectangle(
                            cornerRadius: 8,
                            style: .continuous
                        )
                    )
                }
                .buttonStyle(.plain)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(VeronicaTheme.canvas)
            .navigationSplitViewColumnWidth(
                min: 178,
                ideal: 190,
                max: 220
            )
            .navigationTitle("Veronica")
        } detail: {
            ZStack {
                VeronicaTheme.canvas
                    .ignoresSafeArea()

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
}


struct SectionEmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(VeronicaTheme.accent)

            Text(title)
                .font(.title2.bold())
                .foregroundStyle(VeronicaTheme.ink)

            Text(message)
                .foregroundStyle(VeronicaTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 30)
        .padding(.horizontal, 40)

        Spacer(minLength: 0)
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(VeronicaTheme.accent)

            Text(title)
                .font(.title2.bold())
                .foregroundStyle(VeronicaTheme.ink)

            Text(message)
                .foregroundStyle(VeronicaTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: 620)
        .padding(.horizontal, 28)
        .padding(.vertical, 44)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}
