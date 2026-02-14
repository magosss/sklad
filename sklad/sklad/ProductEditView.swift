//
//  ProductEditView.swift
//  sklad
//

import SwiftUI
import PhotosUI
import UIKit

struct ProductEditView: View {

    let item: APIItem
    let dataStore: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var fullItem: APIItem?
    @State private var isPresentingAddSize = false
    @State private var isPresentingEdit = false
    @State private var isPresentingDeleteItem = false
    @State private var sizeToEdit: APISize?
    @State private var newSizeLabel = ""
    @State private var newSizeBarcode = ""
    @State private var editName = ""
    @State private var editDescription = ""
    @State private var selectedPhoto: PhotosPickerItem?

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
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(size.sizeLabel)
                                Spacer()
                                Text("\(size.quantity) шт.")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            if let code = size.barcode, !code.isEmpty {
                                Text("Штрихкод: \(code)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { sizeToEdit = size }
                    }
                    .onDelete(perform: deleteSizes)
                }
                Button {
                    isPresentingAddSize = true
                } label: {
                    Label("Добавить размер", systemImage: "plus.circle")
                }
            }
            Section {
                Button(role: .destructive) { isPresentingDeleteItem = true } label: {
                    Label("Удалить товар", systemImage: "trash")
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { fullItem = await dataStore.itemWithSizes(id: item.id) }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editName = fullItem?.name ?? item.name
                    editDescription = fullItem?.itemDescription ?? item.itemDescription ?? ""
                    isPresentingEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddSize) { addSizeSheet }
        .sheet(isPresented: $isPresentingEdit) { editItemSheet }
        .sheet(item: $sizeToEdit) { size in
            EditSizeView(item: fullItem ?? item, size: size, dataStore: dataStore)
        }
        .confirmationDialog("Удалить товар?", isPresented: $isPresentingDeleteItem) {
            Button("Удалить", role: .destructive) {
                Task {
                    await dataStore.deleteItem(id: item.id)
                    dismiss()
                }
            }
            Button("Отмена", role: .cancel) { isPresentingDeleteItem = false }
        } message: {
            Text("Товар «\(item.name)» будет удалён со всеми размерами.")
        }
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ItemThumbnailView(photo: fullItem?.photo ?? item.photo, size: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .onChange(of: selectedPhoto) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                await dataStore.updateItem(id: item.id, name: nil, photoData: data, itemDescription: nil)
                                fullItem = await dataStore.itemWithSizes(id: item.id)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fullItem?.name ?? item.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        if let desc = fullItem?.itemDescription ?? item.itemDescription, !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        if let createdAt = fullItem?.createdAt ?? item.createdAt {
                            Text("Создано: \(createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("Всего: \(dataStore.totalQuantity(for: fullItem ?? item)) шт.")
                            .font(.subheadline)
                    }
                    Spacer()
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var editItemSheet: some View {
        NavigationStack {
            Form {
                Section("Наименование") {
                    TextField("Название", text: $editName)
                        .textInputAutocapitalization(.sentences)
                }
                Section("Описание (SEO)") {
                    TextEditor(text: $editDescription)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { isPresentingEdit = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { saveEdit() }
                        .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var addSizeSheet: some View {
        NavigationStack {
            Form {
                Section("Размер") {
                    TextField("Например, S, M, 48", text: $newSizeLabel)
                        .textInputAutocapitalization(.characters)
                }
                Section("Штрихкод") {
                    TextField("Необязательно", text: $newSizeBarcode)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("Новый размер")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        newSizeLabel = ""
                        newSizeBarcode = ""
                        isPresentingAddSize = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { saveNewSize() }
                        .disabled(newSizeLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveEdit() {
        let name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let desc = editDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editDescription
        Task {
            await dataStore.updateItem(id: item.id, name: name, photoData: nil, itemDescription: desc)
            fullItem = await dataStore.itemWithSizes(id: item.id)
            isPresentingEdit = false
        }
    }

    private func saveNewSize() {
        let label = newSizeLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }
        let barcode = newSizeBarcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newSizeBarcode
        Task {
            let ok = await dataStore.createSize(itemId: item.id, sizeLabel: label, barcode: barcode)
            if ok {
                fullItem = await dataStore.itemWithSizes(id: item.id)
                newSizeLabel = ""
                newSizeBarcode = ""
                isPresentingAddSize = false
            }
        }
    }

    private func deleteSizes(at offsets: IndexSet) {
        for index in offsets {
            let size = sizesArray[index]
            Task {
                await dataStore.deleteSize(itemId: item.id, sizeId: size.id)
                fullItem = await dataStore.itemWithSizes(id: item.id)
            }
        }
    }

}
