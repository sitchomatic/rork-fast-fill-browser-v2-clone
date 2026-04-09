import SwiftUI

struct URLAliasListView: View {
    let viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(URLAliasService.profiles) { profile in
                Section(profile.name) {
                    ForEach(profile.aliases) { alias in
                        Button {
                            viewModel.navigateTo(alias.shortcut)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "link")
                                    .font(.subheadline)
                                    .foregroundStyle(.cyan)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(alias.shortcut)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)

                                    Text(alias.url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("URL Aliases")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
        }
    }
}
