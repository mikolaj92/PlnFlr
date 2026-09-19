import Compression
import Foundation

struct ZipArchive {
    let files: [String: Data]

    init(data: Data) throws {
        guard data.count >= 22 else { throw ZipError.notZip }
        files = try Self.read(data)
    }

    subscript(_ name: String) -> Data? { files[name] }
    var names: [String] { Array(files.keys) }
}

enum ZipError: Error { case notZip, truncated, inflate }

private extension ZipArchive {
    static func read(_ data: Data) throws -> [String: Data] {
        guard let eocd = findEOCD(data) else { throw ZipError.notZip }
        let cdOffset = Int(u32(data, eocd + 16))
        let cdSize = Int(u32(data, eocd + 12))
        let cdEnd = cdOffset + cdSize
        guard cdEnd <= data.count else { throw ZipError.truncated }
        var files: [String: Data] = [:]
        var cursor = cdOffset
        while cursor + 46 <= cdEnd {
            guard u32(data, cursor) == 0x02014b50 else { break }
            let method = Int(u16(data, cursor + 10))
            let compressed = Int(u32(data, cursor + 20))
            let uncompressed = Int(u32(data, cursor + 24))
            let nameLen = Int(u16(data, cursor + 28))
            let extraLen = Int(u16(data, cursor + 30))
            let commentLen = Int(u16(data, cursor + 32))
            let localOff = Int(u32(data, cursor + 42))
            let nameStart = cursor + 46
            let nameEnd = nameStart + nameLen
            guard nameEnd <= data.count else { throw ZipError.truncated }
            let name = String(data: data[nameStart..<nameEnd], encoding: .utf8)
                ?? String(decoding: data[nameStart..<nameEnd], as: UTF8.self)
            let payload = try extract(
                data,
                localOff: localOff,
                method: method,
                compressed: compressed,
                uncompressed: uncompressed
            )
            files[name] = payload
            cursor = nameEnd + extraLen + commentLen
        }
        return files
    }

    static func extract(
        _ data: Data,
        localOff: Int,
        method: Int,
        compressed: Int,
        uncompressed: Int
    ) throws -> Data {
        guard localOff + 30 <= data.count else { throw ZipError.truncated }
        guard u32(data, localOff) == 0x04034b50 else { throw ZipError.notZip }
        let nameLen = Int(u16(data, localOff + 26))
        let extraLen = Int(u16(data, localOff + 28))
        let start = localOff + 30 + nameLen + extraLen
        let end = start + compressed
        guard end <= data.count else { throw ZipError.truncated }
        let blob = data[start..<end]
        if method == 0 { return Data(blob) }
        if method == 8 { return try inflate(Data(blob), size: uncompressed) }
        throw ZipError.notZip
    }

    static func inflate(_ src: Data, size: Int) throws -> Data {
        let capacity = max(size, 1)
        var dest = Data(count: capacity)
        let n = dest.withUnsafeMutableBytes { destBuf -> Int in
            src.withUnsafeBytes { srcBuf -> Int in
                guard let dst = destBuf.bindMemory(to: UInt8.self).baseAddress,
                      let source = srcBuf.bindMemory(to: UInt8.self).baseAddress
                else { return 0 }
                return compression_decode_buffer(dst, capacity, source, src.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard n > 0 else { throw ZipError.inflate }
        return dest.prefix(n)
    }

    static func findEOCD(_ data: Data) -> Int? {
        let minOff = max(0, data.count - 22 - 65535)
        var i = data.count - 22
        while i >= minOff {
            if u32(data, i) == 0x06054b50 { return i }
            i -= 1
        }
        return nil
    }
}

private func u16(_ data: Data, _ offset: Int) -> UInt16 {
    UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
}

private func u32(_ data: Data, _ offset: Int) -> UInt32 {
    UInt32(data[offset])
        | UInt32(data[offset + 1]) << 8
        | UInt32(data[offset + 2]) << 16
        | UInt32(data[offset + 3]) << 24
}
