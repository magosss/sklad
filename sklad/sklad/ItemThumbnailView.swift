//
//  ItemThumbnailView.swift
//  sklad
//

import SwiftUI
import UIKit

/// Кэш загруженных фото по URL (по строке URL). Один раз загрузили — показываем сразу на всех вкладках.
final class ImageCache: ObservableObject {
    static let shared = ImageCache()

    private var cache: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "ImageCache", attributes: .concurrent)

    func image(for urlString: String) -> UIImage? {
        queue.sync { cache[urlString] }
    }

    func setImage(_ image: UIImage, for urlString: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.cache[urlString] = image
            DispatchQueue.main.async { self?.objectWillChange.send() }
        }
    }
}

/// Превью фото товара с кэшем: одинаковое поведение на Склад, Добавить и в списках.
struct ItemThumbnailView: View {
    let photo: String?
    var size: CGFloat = 44

    @State private var loadedImage: UIImage?
    @ObservedObject private var imageCache = ImageCache.shared

    private var url: URL? { APIService.shared.photoURL(for: photo) }
    private var urlString: String? { url?.absoluteString }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(width: size, height: size)

            if let img = cachedOrLoadedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "tshirt")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: urlString) {
            guard let urlString = urlString, url != nil else { return }
            if let cached = imageCache.image(for: urlString) {
                loadedImage = cached
                return
            }
            loadedImage = nil
            do {
                let (data, _) = try await URLSession.shared.data(from: url!)
                if let img = UIImage(data: data) {
                    imageCache.setImage(img, for: urlString)
                    loadedImage = img
                }
            } catch {
                loadedImage = nil
            }
        }
    }

    private var cachedOrLoadedImage: UIImage? {
        if let img = loadedImage { return img }
        guard let urlString = urlString else { return nil }
        return imageCache.image(for: urlString)
    }
}
