import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

func requestBodyString(_ request: URLRequest) -> String {
    if let httpBody = request.httpBody {
        return String(decoding: httpBody, as: UTF8.self)
    }
    guard let stream = request.httpBodyStream else { return "" }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        if read <= 0 { break }
        data.append(buffer, count: read)
    }

    return String(decoding: data, as: UTF8.self)
}

