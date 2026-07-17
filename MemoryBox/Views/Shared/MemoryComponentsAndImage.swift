//
//  MemoryComponentsAndImage.swift
//  MemoryBox
//

import SwiftUI
import PhotosUI
import Photos
import ImageIO
import CoreLocation
import MapKit
#if canImport(UIKit)
import UIKit
#endif

struct FeaturedMemoryCard: View {
    let memory: LoveMemory

    var body: some View {
        MemoryPhotoCard(memory: memory, style: .featured)
            .shadow(color: memory.mood.color.opacity(0.18), radius: 14, y: 8)
    }
}

enum MemoryPhotoCardStyle {
    case featured
    case grid
    case compact

    var height: CGFloat {
        switch self {
        case .featured:
            return 250
        case .grid:
            return 190
        case .compact:
            return 160
        }
    }

    var width: CGFloat? {
        switch self {
        case .compact:
            return 150
        default:
            return nil
        }
    }

    var titleFont: Font {
        switch self {
        case .featured:
            return .title2.bold()
        default:
            return .headline
        }
    }
}

struct MemoryPhotoCard: View {
    let memory: LoveMemory
    let style: MemoryPhotoCardStyle
    var rotatesImages: Bool = false
    @State private var imageIndex = 0

    private var visibleImagePath: String? {
        guard !memory.imagePaths.isEmpty else { return nil }
        return memory.imagePaths[imageIndex % memory.imagePaths.count]
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MemoryVisual(memory: memory, imagePathOverride: visibleImagePath)
                .id(visibleImagePath ?? "empty-\(memory.id.uuidString)")
                .transition(.opacity.combined(with: .scale(scale: 1.03)))

            LinearGradient(
                colors: [.clear, .black.opacity(0.62)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(memory.date.pastRelativeText, systemImage: memory.displayKind.icon)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))

                    Spacer()

                    if memory.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }

                Text(memory.title)
                    .font(style.titleFont)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
            .padding(14)
        }
        .frame(width: style.width)
        .frame(height: style.height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: memory.imagePaths) {
            await rotateImagesIfNeeded()
        }
    }

    @MainActor
    private func rotateImagesIfNeeded() async {
        imageIndex = 0
        guard rotatesImages, memory.imagePaths.count > 1 else { return }

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation(.easeInOut(duration: 0.38)) {
                imageIndex = (imageIndex + 1) % memory.imagePaths.count
            }
        }
    }
}

struct MemoryVisual: View {
    let memory: LoveMemory
    var imagePathOverride: String? = nil

    var body: some View {
        ZStack {
            if let imagePath = imagePathOverride ?? memory.imagePath {
                StoredImageView(imagePath: imagePath)
            } else {
                LinearGradient(
                    colors: [memory.mood.color.opacity(0.92), memory.mood.color.opacity(0.42), Color.white.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: memory.symbolName)
                    .font(.system(size: 78, weight: .thin))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 6)

                Image(systemName: memory.mood.icon)
                    .font(.system(size: 150, weight: .thin))
                    .foregroundStyle(.white.opacity(0.12))
                    .offset(x: 46, y: -36)
            }
        }
    }
}

struct StoredImageView: View {
    let imagePath: String

    var body: some View {
        #if canImport(UIKit)
        if let image = ImageFileStore.uiImage(for: imagePath) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color.gray.opacity(0.2)
        }
        #else
        Color.gray.opacity(0.2)
        #endif
    }
}

struct LoadedPhoto {
    let imagePath: String?
    let takenDate: Date?
    let place: String?
}

struct PhotoMetadata {
    let takenDate: Date?
    let location: CLLocation?
}

enum ImageFileStore {
    private static let rootDirectoryName = "MemoryBoxImages"

    static func save(data: Data?, category: String, id: String? = nil) -> String? {
        guard let data else { return nil }

        let fileName = "\(id ?? UUID().uuidString).image"
        let relativePath = "\(rootDirectoryName)/\(category)/\(fileName)"
        let fileURL = applicationSupportDirectory.appendingPathComponent(relativePath)

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
            return relativePath
        } catch {
            assertionFailure("Unable to save image file: \(error.localizedDescription)")
            return nil
        }
    }

    static func data(for relativePath: String?) -> Data? {
        guard let relativePath else { return nil }
        return try? Data(contentsOf: fileURL(for: relativePath))
    }

    static func restoreIfNeeded(data: Data, relativePath: String) {
        let fileURL = fileURL(for: relativePath)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Unable to restore image file: \(error.localizedDescription)")
        }
    }

    #if canImport(UIKit)
    static func uiImage(for relativePath: String) -> UIImage? {
        UIImage(contentsOfFile: fileURL(for: relativePath).path)
    }
    #endif

    private static func fileURL(for relativePath: String) -> URL {
        applicationSupportDirectory.appendingPathComponent(relativePath)
    }

    private static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
}

enum ImageLoader {
    static func data(from item: PhotosPickerItem?) async -> Data? {
        guard let item else { return nil }
        return try? await item.loadTransferable(type: Data.self)
    }

    static func photo(from item: PhotosPickerItem?) async -> LoadedPhoto {
        let metadata = metadata(from: item)
        let imageData = await data(from: item)
        let location = metadata.location ?? imageData.flatMap(photoLocation(from:))
        return LoadedPhoto(
            imagePath: ImageFileStore.save(data: imageData, category: "memories"),
            takenDate: metadata.takenDate ?? imageData.flatMap(photoDate(from:)),
            place: await placeName(from: location)
        )
    }

    static func photos(from items: [PhotosPickerItem]) async -> [LoadedPhoto] {
        var photos: [LoadedPhoto] = []
        for item in items {
            photos.append(await photo(from: item))
        }
        return photos
    }

    static func imagePath(from item: PhotosPickerItem?, category: String, id: String? = nil) async -> String? {
        ImageFileStore.save(data: await data(from: item), category: category, id: id)
    }

    private static func photoDate(from imageData: Data) -> Date? {
        guard
            let source = CGImageSourceCreateWithData(imageData as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            return nil
        }

        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let dateString = exif?[kCGImagePropertyExifDateTimeOriginal] as? String
            ?? exif?[kCGImagePropertyExifDateTimeDigitized] as? String
            ?? tiff?[kCGImagePropertyTIFFDateTime] as? String

        guard let dateString else { return nil }
        return exifDateFormatter.date(from: dateString)
    }

    private static func metadata(from item: PhotosPickerItem?) -> PhotoMetadata {
        guard
            let identifier = item?.itemIdentifier,
            let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
        else {
            return PhotoMetadata(takenDate: nil, location: nil)
        }

        return PhotoMetadata(takenDate: asset.creationDate, location: asset.location)
    }

    private static func photoLocation(from imageData: Data) -> CLLocation? {
        guard
            let source = CGImageSourceCreateWithData(imageData as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any],
            let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
            let longitude = gps[kCGImagePropertyGPSLongitude] as? Double
        else {
            return nil
        }

        let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef] as? String
        let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef] as? String
        let signedLatitude = latitudeRef == "S" ? -latitude : latitude
        let signedLongitude = longitudeRef == "W" ? -longitude : longitude
        return CLLocation(latitude: signedLatitude, longitude: signedLongitude)
    }

    private static func placeName(from location: CLLocation?) async -> String? {
        guard let location else { return nil }
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return coordinateText(from: location)
        }

        let mapItems = await withCheckedContinuation { continuation in
            request.getMapItems { mapItems, _ in
                continuation.resume(returning: mapItems)
            }
        }

        guard let mapItem = mapItems?.first else {
            return coordinateText(from: location)
        }

        let displayName = mapItem.name?.trimmed
        let fullAddress = mapItem.addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)?.trimmed.replacingOccurrences(of: "\n", with: ", ")
        let parts = [displayName, fullAddress]
            .compactMap { $0 }
            .filter { !$0.isEmpty && $0 != "Unknown Location" }
            .uniqued()

        return parts.isEmpty ? coordinateText(from: location) : parts.joined(separator: ", ")
    }

    private static func coordinateText(from location: CLLocation) -> String {
        "\(location.coordinate.latitude), \(location.coordinate.longitude)"
    }

    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()
}
