//
//  ProductsListView.swift
//  sklad
//

import SwiftUI
import PhotosUI
import UIKit

struct ProductsListView: View {

    @Environment(DataStore.self) private var dataStore
    @State private var isPresentingAddItem = false
    @State private var newItemName = ""
    @State private var newItemDescription = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var itemToDelete: APIItem?

    var body: some View {
        Group {
            if dataStore.items.isEmpty && !dataStore.isLoading {
                ContentUnavailableView {
                    Label("Товаров нет", systemImage: "shippingbox")
                } description: {
                    Text("Нажмите «+», чтобы добавить первое наименование.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(dataStore.items) { item in
                        NavigationLink {
                            ProductEditView(item: item, dataStore: dataStore)
                        } label: {
                            HStack(spacing: 12) {
                                itemThumb(item)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.headline)
                                    Text("\(dataStore.totalQuantity(for: item)) шт. всего")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: requestDeleteItems)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Товары")
        .task { await dataStore.loadItems() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    newItemName = ""
                    newItemDescription = ""
                    selectedPhoto = nil
                    selectedPhotoData = nil
                    isPresentingAddItem = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddItem) { addItemSheet }
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

    private func itemThumb(_ item: APIItem) -> some View {
        ItemThumbnailView(photo: item.photo, size: 44)
    }

    private var addItemSheet: some View {
        NavigationStack {
            Form {
                Section("Наименование") {
                    TextField("Например, худи oversize", text: $newItemName)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Описание (SEO)") {
                    TextEditor(text: $newItemDescription)
                        .frame(minHeight: 60)
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
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { isPresentingAddItem = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { saveNewItem() }
                        .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveNewItem() {
        let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let desc = newItemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newItemDescription
        Task {
            let ok = await dataStore.createItem(name: name, photoData: selectedPhotoData, itemDescription: desc)
            if ok {
                await MainActor.run { isPresentingAddItem = false }
            }
        }
    }

    private func requestDeleteItems(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        itemToDelete = dataStore.items[index]
    }

}
