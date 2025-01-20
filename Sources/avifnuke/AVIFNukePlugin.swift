//
//  AVIFNukePlugin.swift
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 26/06/2022.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import Nuke
#if canImport(avif)
import avif
#endif
#if SWIFT_PACKAGE
@preconcurrency import avifc
#endif


public final class AVIFNukePlugin: Nuke.ImageDecoding {
    
    private let isNukeViewerEnabled: Bool
    private lazy var decoder: AVIFDataDecoder = AVIFDataDecoder()
    
    public lazy var width: CGFloat = 0
    public lazy var height: CGFloat = 0
    public lazy var needData: Bool = false

    public init(isNuke isNukeViewerEnabled: Bool = false, width: CGFloat = 0, height: CGFloat = 0) {
        self.isNukeViewerEnabled = isNukeViewerEnabled
        if width != 0 {
            self.width = width
        }
        if height != 0 {
            self.height = height
        }
    }
    
    public func decode(_ data: Data) throws -> ImageContainer {
        guard data.isAVIFFormat else { throw ImageDecodingError.unknown }
        // guard let image = AVIFDecoder.decode(data) else { throw AVIFNukePluginDecodeError() }
        if isNukeViewerEnabled {
            var size: CGSize = try! decoder.readSize(data) as! CGSize
            if self.width != 0 {
                if self.height != 0 {
                    size.height = self.height
                } else {
                    let height = self.width * size.height / size.width
                    size.height = height
                }
                size.width = self.width
            } else if self.height != 0 {
                if self.width == 0 {
                    let width = self.height * size.width / size.height
                    size.width = width
                }
                size.height = self.height
            }
            guard let image = try? decoder.decode(InputStream(data: data), sampleSize: size, maxContentSize: 0, scale: 1) else { throw AVIFNukePluginDecodeError() }
            if needData {
                return ImageContainer(image: image, type: .avif, data: data)
            } else {
                return ImageContainer(image: image, type: .avif)
            }
        } else {
            guard let size = try? decoder.readSize(data) else { throw AVIFNukePluginDecodeError() }
            return ImageContainer(image: UIImage(), type: .avif, data: data, userInfo: ["width": (size as! CGSize).width])
        }
    }

    public func decodePartiallyDownloadedData(_ data: Data) -> ImageContainer? {
        guard data.isAVIFFormat else { return nil }
        guard let image = decoder.incrementallyDecode(data) else { return nil }
        if isNukeViewerEnabled {
            if needData {
                return ImageContainer(image: image, type: .avif, data: data)
            } else {
                return ImageContainer(image: image, type: .avif)
            }
        } else {
            return ImageContainer(image: UIImage(), type: .avif, data: data)
        }
    }

    public struct AVIFNukePluginDecodeError: LocalizedError, CustomNSError {
        public var errorDescription: String {
            "AVIF doesn't seems to be valid"
        }

        public var errorUserInfo: [String : Any] {
            [NSLocalizedDescriptionKey: errorDescription]
        }
    }

}

// MARK: - check avif format data.
extension AVIFNukePlugin {

    public func enable() {
        Nuke.ImageDecoderRegistry.shared.register { (context) -> ImageDecoding? in
            self.enable(context: context)
        }
    }

    public func enable(context: Nuke.ImageDecodingContext) -> Nuke.ImageDecoding? {
        return context.data.isAVIFFormat ? self : nil
    }

}

extension AssetType {
    public static let avif: AssetType = "public.avif"
    
    func make(_ data: Data) -> AssetType? {
        func _match(_ numbers: [UInt8?], offset: Int = 0) -> Bool {
            guard data.count >= numbers.count else {
                return false
            }
            return zip(numbers.indices, numbers).allSatisfy { index, number in
                guard let number else { return true }
                guard (index + offset) < data.count else { return false }
                return data[index + offset] == number
            }
        }

        // JPEG magic numbers https://en.wikipedia.org/wiki/JPEG
        if _match([0xFF, 0xD8, 0xFF]) { return .jpeg }

        // PNG Magic numbers https://en.wikipedia.org/wiki/Portable_Network_Graphics
        if _match([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return .png }

        // GIF magic numbers https://en.wikipedia.org/wiki/GIF
        if _match([0x47, 0x49, 0x46]) { return .gif }

        // WebP magic numbers https://en.wikipedia.org/wiki/List_of_file_signatures
        if _match([0x52, 0x49, 0x46, 0x46, nil, nil, nil, nil, 0x57, 0x45, 0x42, 0x50]) { return .webp }

        // see https://stackoverflow.com/questions/21879981/avfoundation-avplayer-supported-formats-no-vob-or-mpg-containers
        // https://en.wikipedia.org/wiki/List_of_file_signatures
        if _match([0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D], offset: 4) { return .mp4 }

        // https://www.garykessler.net/library/file_sigs.html
        if _match([0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x32], offset: 4) { return .m4v }

        if _match([0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x56, 0x20], offset: 4) { return .m4v }

        // MOV magic numbers https://www.garykessler.net/library/file_sigs.html
        if _match([0x66, 0x74, 0x79, 0x70, 0x71, 0x74, 0x20, 0x20], offset: 4) { return .mov }
        
        if _match([0x66, 0x74, 0x79, 0x70, 0x61, 0x76, 0x69], offset: 4) { return .avif }

        // Either not enough data, or we just don't support this format.
        return nil
    }
}
