import SwiftUI

/// The root screen of the watch app.
///
/// Shows a compact, watch-friendly list of items with loading and error states,
/// and provides navigation to `SettingsView`.
struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        content
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .task {
                await viewModel.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .containerBackground(.blue.gradient, for: .navigation)
        } else if let message = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Couldn't Load", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
                    .font(.footnote)
            } actions: {
                Button("Retry") {
                    Task { await viewModel.load() }
                }
            }
        } else {
            List {
                ForEach(viewModel.items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .containerBackground(.blue.gradient, for: .navigation)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
