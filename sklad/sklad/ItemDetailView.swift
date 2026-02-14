//
//  ItemDetailView.swift
//  sklad
//

import SwiftUI

struct ItemDetailView: View {

    let item: APIItem
    let dataStore: DataStore
    @State private var fullItem: APIItem?

    private var sizesArray: [APISize] {
        (fullItem?.sizes ?? item.sizes ?? []).sorted { $0.sizeLabel < $1.sizeLabel }
    }

    var body: some View {
        List {
            headerSection
            Section("Размеры") {
                if sizesArray.isEmpty {
                    Text("Пока нет размеров")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sizesArray) { size in
                        HStack {
                            Text(size.sizeLabel)
                            Spacer()
                            Text("\(size.quantity) шт.")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            Section {
                NavigationLink {
                    SupplyHistoryView(itemId: item.id)
                } label: {
                    Label("История поставок", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            fullItem = await dataStore.itemWithSizes(id: item.id)
        }
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ItemThumbnailView(photo: fullItem?.photo ?? item.photo, size: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Всего на складе: \(dataStore.totalQuantity(for: fullItem ?? item)) шт.")
                            .font(.subheadline)
                    }
                    Spacer()
                }
            }
            .padding(.vertical, 4)
        }
    }

}
