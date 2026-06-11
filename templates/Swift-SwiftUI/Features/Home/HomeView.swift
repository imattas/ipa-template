//
//  HomeView.swift
//  Swift-SwiftUI
//
//  The root content screen. Renders the list of items with loading and error
//  states, supports pull-to-refresh, and navigates to detail/settings through
//  the shared AppRouter.
//

import SwiftUI

struct HomeView: View {
    /// View model owned by this screen. `@State` keeps the @Observable model
    /// alive across re-renders.
    @State private var viewModel: HomeViewModel

    /// The shared router, supplied via the environment by AppEntry.
    @Environment(AppRouter.self) private var router

    init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        content
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        router.push(.settings)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let message = viewModel.errorMessage, viewModel.items.isEmpty {
            ContentUnavailableView {
                Label("Couldn't Load Items", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") {
                    Task { await viewModel.load() }
                }
            }
        } else if viewModel.items.isEmpty && !viewModel.isLoading {
            ContentUnavailableView(
                "No Items",
                systemImage: "tray",
                description: Text("Pull to refresh or check back later.")
            )
        } else {
            itemsList
        }
    }

    private var itemsList: some View {
        List {
            ForEach(displayedItems) { item in
                Button {
                    router.push(.detail(item.id))
                } label: {
                    ItemRow(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .redactedWhileLoading(viewModel.isLoading && viewModel.items.isEmpty)
        .listStyle(.inset)
    }

    /// When loading the first page, show skeleton placeholders.
    private var displayedItems: [Item] {
        if viewModel.isLoading && viewModel.items.isEmpty {
            return (0..<5).map { Item(id: -1 - $0, title: "Loading item", subtitle: "Placeholder") }
        }
        return viewModel.items
    }
}

private struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview("Loaded") {
    NavigationStack {
        HomeView(viewModel: HomeViewModel(api: MockAPIClient()))
    }
    .environment(AppRouter())
}

#Preview("Error") {
    NavigationStack {
        HomeView(
            viewModel: HomeViewModel(
                api: MockAPIClient(error: APIError.server(status: 500))
            )
        )
    }
    .environment(AppRouter())
}
