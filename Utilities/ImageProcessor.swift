import UIKit

enum ImageProcessor {
    static func compressedJPEGData(
        from image: UIImage,
        maxDimension: CGFloat = 768,
        compressionQuality: CGFloat = 0.66,
        maximumByteCount: Int = 900_000
    ) throws -> Data {
        guard image.size.width > 0, image.size.height > 0 else {
            throw ImageProcessorError.invalidImageData
        }

        let targetSize = scaledSize(for: image.size, maxDimension: maxDimension)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        var quality = min(max(compressionQuality, 0.35), 0.9)
        guard var data = resizedImage.jpegData(compressionQuality: quality) else {
            throw ImageProcessorError.compressionFailed
        }

        while data.count > maximumByteCount, quality > 0.35 {
            quality = max(quality - 0.1, 0.35)
            guard let recompressedData = resizedImage.jpegData(compressionQuality: quality) else {
                throw ImageProcessorError.compressionFailed
            }
            data = recompressedData
        }

        return data
    }

    private static func scaledSize(for size: CGSize, maxDimension: CGFloat) -> CGSize {
        let largestDimension = max(size.width, size.height)

        guard largestDimension > maxDimension else {
            return size
        }

        let scale = maxDimension / largestDimension
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

enum ImageProcessorError: LocalizedError {
    case invalidImageData
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "The selected image could not be loaded."
        case .compressionFailed:
            return "The selected image could not be compressed."
        }
    }
}
