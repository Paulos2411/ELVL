import SwiftUI

struct WatchlistPickerSheet: View {
    let title: String
    let watchlists: [Watchlist]
    let onCreateList: (String) -> Void
    let onSelect: (Watchlist) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newListName: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                List {
                    Section("Add to") {
                        ForEach(watchlists) { list in
                            Button {
                                onSelect(list)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(list.name)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text("\(list.items.count)")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .padding(.vertical, 6)
                            }
                            .listRowBackground(Theme.surface)
                        }
                    }

                    Section("New watchlist") {
                        TextField("Name", text: $newListName)
                        Button("Create") {
                            onCreateList(newListName)
                            newListName = ""
                        }
                        .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

