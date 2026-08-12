//
//  MemoryComponentsAndImage.swift
//  MemoryBox
//

import SwiftUI
import PhotosUI
import Photos
import ImageIO
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

struct FeaturedMemoryCard: View {
    let memory: LoveMemory

    private var featuredImagePath: String? {
        memory.imagePaths.first ?? memory.imagePath
    }

    private var displayAspectRatio: CGFloat {
        guard let featuredImagePath else { return 4 / 3 }
        return ImageFileStore.displayAspectRatio(for: featuredImagePath) ?? 4 / 3
    }

    var body: some View {
        MemoryPhotoCard(memory: memory, style: .featured)
            .aspectRatio(displayAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .shadow(color: memory.mood.color.opacity(0.18), radius: 14, y: 8)
    }
}

enum MemoryPhotoCardStyle {
    case featured
    case grid
    case compact
    case collage

    var height: CGFloat {
        switch self {
        case .featured:
            return 250
        case .grid:
            return 190
        case .compact:
            return 160
        case .collage:
            return 0
        }
    }

    var width: CGFloat? {
        switch self {
        case .compact:
            return 150
        case .collage:
            return nil
        default:
            return nil
        }
    }

    var titleFont: Font {
        switch self {
        case .featured:
            return .title2.bold()
        case .collage:
            return .subheadline.weight(.bold)
        case .compact:
            return .system(size: 14, weight: .bold)
        default:
            return .headline
        }
    }

    var metaFont: Font {
        switch self {
        case .compact:
            return .system(size: 10, weight: .semibold)
        default:
            return .caption2.weight(.bold)
        }
    }

    var captionPadding: CGFloat {
        switch self {
        case .collage:
            return 10
        case .compact:
            return 8
        default:
            return 12
        }
    }

    var titleLineLimit: Int {
        switch self {
        case .collage:
            return 1
        case .compact:
            return 2
        default:
            return 2
        }
    }
}

struct MemoryPhotoCard: View {
    let memory: LoveMemory
    let style: MemoryPhotoCardStyle
    var rotatesImages: Bool = false
    @State private var imageIndex = 0

    private var imageCount: Int {
        max(memory.imagePaths.count, 1)
    }

    private var visibleImagePath: String? {
        guard !memory.imagePaths.isEmpty else { return nil }
        return memory.imagePaths[imageIndex % memory.imagePaths.count]
    }

    /// Cứ 2 ảnh ẩn ngày/tháng thì 1 ảnh hiện (show → hide → hide → …).
    private var showsCaption: Bool {
        !rotatesImages || imageIndex % 3 == 0
    }

    var body: some View {
        ZStack {
            rotatingImages
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .allowsHitTesting(false)
        }
        .applyMemoryPhotoCardFrame(style: style)
        .overlay(alignment: .bottom) {
            captionBar
                .opacity(showsCaption ? 1 : 0)
                .animation(.easeInOut(duration: 0.35), value: showsCaption)
                .geometryGroup()
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: memory.imagePaths) {
            await rotateImagesIfNeeded()
        }
    }

    /// Ảnh xếp chồng cùng frame — chỉ đổi opacity, không insert/remove (tránh nhảy layout).
    private var rotatingImages: some View {
        ZStack {
            if memory.imagePaths.isEmpty {
                filledVisual(path: nil)
            } else if rotatesImages, memory.imagePaths.count > 1 {
                ForEach(Array(memory.imagePaths.enumerated()), id: \.offset) { index, path in
                    filledVisual(path: path)
                        .opacity(index == imageIndex % imageCount ? 1 : 0)
                }
            } else {
                filledVisual(path: visibleImagePath)
            }
        }
        .animation(.easeInOut(duration: 0.38), value: imageIndex)
        .geometryGroup()
    }

    private func filledVisual(path: String?) -> some View {
        MemoryVisual(memory: memory, imagePathOverride: path)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
    }

    private var captionBar: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: memory.displayKind.icon)
                    .font(style.metaFont)

                Text(memory.date.pastRelativeText)
                    .font(style.metaFont)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if memory.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(style.metaFont)
                }
            }
            .foregroundStyle(.white.opacity(0.92))

            Text(styledTitle)
                .foregroundStyle(.white)
                .lineLimit(style.titleLineLimit)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(style.captionPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.55), .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    /// Title với line height sát (cách ~1pt), tránh bị cắt/lệch trên card nhỏ.
    private var styledTitle: AttributedString {
        var text = AttributedString(memory.title)
        text.font = style.titleFont

        let lineHeight: CGFloat
        switch style {
        case .compact:
            lineHeight = 15
        case .collage:
            lineHeight = 16
        case .featured:
            lineHeight = 28
        default:
            lineHeight = 20
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        paragraph.lineBreakMode = .byTruncatingTail
        text.paragraphStyle = paragraph
        return text
    }

    @MainActor
    private func rotateImagesIfNeeded() async {
        imageIndex = 0
        guard rotatesImages, memory.imagePaths.count > 1 else { return }

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            // Không withAnimation toàn cục — tránh kéo overlay lệch vị trí.
            imageIndex = (imageIndex + 1) % memory.imagePaths.count
        }
    }
}


private extension View {
    @ViewBuilder
    func applyMemoryPhotoCardFrame(style: MemoryPhotoCardStyle) -> some View {
        switch style {
        case .featured:
            frame(maxWidth: .infinity)
        case .collage:
            frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            frame(width: style.width)
                .frame(height: style.height)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            Color(.tertiarySystemFill)
        }
        #else
        Color(.tertiarySystemFill)
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

    static func delete(_ relativePath: String?) {
        guard let relativePath else { return }
        let fileURL = fileURL(for: relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try? FileManager.default.removeItem(at: fileURL)
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

    static func shareURL(for relativePath: String) -> URL {
        fileURL(for: relativePath)
    }

    static func displayAspectRatio(for relativePath: String) -> CGFloat? {
        guard let image = uiImage(for: relativePath), image.size.height > 0 else { return nil }
        return image.size.width / image.size.height
    }
    #endif

    private static func fileURL(for relativePath: String) -> URL {
        applicationSupportDirectory.appendingPathComponent(relativePath)
    }

    private static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    static func compressedJPEGData(from data: Data, maxDimension: CGFloat = 1280, quality: CGFloat = 0.78) -> Data? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        return image.compressedJPEGData(maxDimension: maxDimension, quality: quality) ?? data
        #else
        return data
        #endif
    }
}

#if canImport(UIKit)
extension UIImage {
    func compressedJPEGData(maxDimension: CGFloat = 1280, quality: CGFloat = 0.78) -> Data? {
        let largestSide = max(size.width, size.height)
        let scale = largestSide > maxDimension ? maxDimension / largestSide : 1
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
#endif

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

        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        guard let placemark = placemarks?.first else {
            return coordinateText(from: location)
        }

        let parts = [
            placemark.name,
            placemark.thoroughfare,
            placemark.subLocality,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country
        ]
            .compactMap { $0?.trimmed }
            .filter { !$0.isEmpty }
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
