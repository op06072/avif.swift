//
//  Data+AVIFFormat.swift
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 05/12/2021.
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

//https://www.garykessler.net/library/file_sigs.html
import Foundation

private let fileHeaderIndex: Int = 4

private let avifBytes: [UInt8] = [
    0x66, 0x74, 0x79, 0x70, // ftyp
    0x61, 0x76, 0x69  // avif or avis
]
private let magicBytesEndIndex: Int = fileHeaderIndex+avifBytes.count
// MARK: - AVIF Format Testing
extension Data {

    internal var isAVIFFormat: Bool {
        guard magicBytesEndIndex < count else { return false }
        let bytesStart = index(startIndex, offsetBy: fileHeaderIndex)
        let data = subdata(in: bytesStart..<magicBytesEndIndex)
        return data.elementsEqual(avifBytes)
    }
}
