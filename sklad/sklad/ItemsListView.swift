//
//  ItemsListView.swift
//  sklad
//

import SwiftUI
import UIKit
import PhotosUI

struct ItemsListView: View {

    @Environment(DataStore.self) private var dataStore

    @State private var isPresentingAdd = false
    @State private var newItemName = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var itemToDelete: APIItem?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Склад")
                .task { await dataStore.loadItems() }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        NavigationLink {
                            ReportsView(dataStore: dataStore)
                        } label: {
                            Image(systemName: "chart.bar.doc.horizontal")
                        }
                        .accessibilityLabel("Отчёт")
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isPresentingAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Добавить наименование")
                    }
                }
                .sheet(isPresented: $isPresentingAdd) {
                    addItemSheet
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if dataStore.items.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Наименований пока нет")
                    .font(.headline)
                Text("Нажмите «+», чтобы добавить первое изделие.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
        } else {
            List {
                ForEach(dataStore.items) { item in
                    NavigationLink {
                        ItemDetailView(item: item, dataStore: dataStore)
                    } label: {
                        itemRow(for: item)
                    }
                }
                .onDelete(perform: requestDeleteItems)
            }
            .listStyle(.insetGrouped)
            .confirmationDialog("Удалить наименование?", isPresented: Binding(
                get: { itemToDelete != nil },
                set: { if !$0 { itemToDelete = nil } }
            )) {
                Button("Да", role: .destructive) {
                    if let item = itemToDelete {
                        Task { await dataStore.deleteItem(id: item.id) }
                    }
                    itemToDelete = nil
                }
                Button("Нет", role: .cancel) { itemToDelete = nil }
            } message: {
                if let item = itemToDelete {
                    Text("Удалить «\(item.name)»?")
                }
            }
        }
    }

    private func itemRow(for item: APIItem) -> some View {
        HStack(spacing: 12) {
            ItemThumbnailView(photo: item.photo, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                Text("Всего: \(dataStore.totalQuantity(for: item)) шт.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var addItemSheet: some View {
        NavigationStack {
            Form {
                Section("Наименование") {
                    TextField("Например, худи oversize", text: $newItemName)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Фото") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            if let data = selectedPhotoData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            } else {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                            Text(selectedPhotoData != nil ? "Изменить фото" : "Добавить из галереи")
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                selectedPhotoData = data
                            }
                        }
                    }
                }
            }
            .navigationTitle("Новое изделие")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        newItemName = ""
                        selectedPhoto = nil
                        selectedPhotoData = nil
                        isPresentingAdd = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { saveNewItem() }
                        .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveNewItem() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            let ok = await dataStore.createItem(name: trimmed, photoData: selectedPhotoData, itemDescription: nil)
            await MainActor.run {
                if ok {
                    newItemName = ""
                    selectedPhoto = nil
                    selectedPhotoData = nil
                    isPresentingAdd = false
                }
            }
        }
    }

    private func requestDeleteItems(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        itemToDelete = dataStore.items[index]
    }

}

#Preview {
    ItemsListView()
        .environment(DataStore())
}
