import Foundation
import zlib

/// 最小 ZIP 写入器（store 压缩方式），用于大批量原图导出。
public final class ZipArchiveWriter: @unchecked Sendable {
    private struct Entry {
        let zipPath: String
        let localHeaderOffset: UInt32
        let crc32: UInt32
        let size: UInt32
    }

    private let outputURL: URL
    private let fileHandle: FileHandle
    private var entries: [Entry] = []
    private let lock = NSLock()

    public init(outputURL: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }
        fileManager.createFile(atPath: outputURL.path, contents: nil)
        self.outputURL = outputURL
        self.fileHandle = try FileHandle(forWritingTo: outputURL)
    }

    public func appendFile(at sourceURL: URL, zipPath: String) throws {
        let data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        try appendData(data, zipPath: zipPath)
    }

    public func appendData(_ data: Data, zipPath: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let offset = UInt32(fileHandle.offsetInFile)
        let crc = data.withUnsafeBytes { buffer -> UInt32 in
            guard let base = buffer.baseAddress?.assumingMemoryBound(to: Bytef.self) else {
                return 0
            }
            return UInt32(crc32(0, base, uInt(buffer.count)))
        }

        try writeLocalFileHeader(
            zipPath: zipPath,
            crc32: crc,
            compressedSize: UInt32(data.count),
            uncompressedSize: UInt32(data.count),
            localHeaderOffset: offset
        )
        try fileHandle.write(contentsOf: data)

        entries.append(
            Entry(
                zipPath: zipPath,
                localHeaderOffset: offset,
                crc32: crc,
                size: UInt32(data.count)
            )
        )
    }

    public func close() throws {
        lock.lock()
        defer { lock.unlock() }

        let centralDirectoryOffset = UInt32(fileHandle.offsetInFile)
        var centralDirectorySize: UInt32 = 0

        for entry in entries {
            let record = try makeCentralDirectoryRecord(for: entry)
            try fileHandle.write(contentsOf: record)
            centralDirectorySize += UInt32(record.count)
        }

        try fileHandle.write(contentsOf: makeEndOfCentralDirectoryRecord(
            entryCount: UInt16(entries.count),
            centralDirectorySize: centralDirectorySize,
            centralDirectoryOffset: centralDirectoryOffset
        ))
        try fileHandle.close()
    }

    public var archiveURL: URL { outputURL }

    // MARK: - Private

    private func writeLocalFileHeader(
        zipPath: String,
        crc32: UInt32,
        compressedSize: UInt32,
        uncompressedSize: UInt32,
        localHeaderOffset: UInt32
    ) throws {
        let pathData = Data(zipPath.utf8)
        var header = Data()
        header.appendUInt32(0x0403_4B50)
        header.appendUInt16(20)
        header.appendUInt16(0)
        header.appendUInt16(0)
        header.appendUInt16(0)
        header.appendUInt16(0)
        header.appendUInt32(crc32)
        header.appendUInt32(compressedSize)
        header.appendUInt32(uncompressedSize)
        header.appendUInt16(UInt16(pathData.count))
        header.appendUInt16(0)
        header.append(pathData)
        try fileHandle.write(contentsOf: header)
        _ = localHeaderOffset
    }

    private func makeCentralDirectoryRecord(for entry: Entry) throws -> Data {
        let pathData = Data(entry.zipPath.utf8)
        var record = Data()
        record.appendUInt32(0x0201_4B50)
        record.appendUInt16(20)
        record.appendUInt16(20)
        record.appendUInt16(0)
        record.appendUInt16(0)
        record.appendUInt16(0)
        record.appendUInt16(0)
        record.appendUInt32(entry.crc32)
        record.appendUInt32(entry.size)
        record.appendUInt32(entry.size)
        record.appendUInt16(UInt16(pathData.count))
        record.appendUInt16(0)
        record.appendUInt16(0)
        record.appendUInt16(0)
        record.appendUInt16(0)
        record.appendUInt32(0)
        record.appendUInt32(entry.localHeaderOffset)
        record.append(pathData)
        return record
    }

    private func makeEndOfCentralDirectoryRecord(
        entryCount: UInt16,
        centralDirectorySize: UInt32,
        centralDirectoryOffset: UInt32
    ) -> Data {
        var record = Data()
        record.appendUInt32(0x0605_4B50)
        record.appendUInt16(0)
        record.appendUInt16(0)
        record.appendUInt16(entryCount)
        record.appendUInt16(entryCount)
        record.appendUInt32(centralDirectorySize)
        record.appendUInt32(centralDirectoryOffset)
        record.appendUInt16(0)
        return record
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
