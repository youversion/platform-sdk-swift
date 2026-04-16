import Foundation
#if canImport(os)
import os
#endif

/// A lightweight logger used by the YouVersion Platform SDK.
///
/// By default, only messages at ``Level/error`` or higher are emitted, keeping
/// client consoles quiet. Lower the level (for example to ``Level/debug``) to
/// surface more detail while debugging, or set it to ``Level/off`` to silence
/// the SDK entirely.
///
/// ```swift
/// YouVersionPlatformLogger.level = .debug
/// ```
///
/// On Apple platforms messages flow through `os.Logger`, so they appear in
/// Xcode's debug console and in Console.app under the
/// `com.youversion.platform-sdk` subsystem. On other platforms (notably
/// Linux, used for SDK test runs) messages are written to standard output.
public enum YouVersionPlatformLogger {

    /// Severity levels, mirroring the levels exposed by `os.Logger`.
    ///
    /// Levels are ordered from most verbose to most severe:
    /// ``debug`` < ``info`` < ``notice`` < ``error`` < ``fault`` < ``off``.
    public enum Level: Int, Sendable, Comparable {
        case debug
        case info
        case notice
        case error
        case fault
        case off

        public static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// The minimum severity emitted by the SDK. Defaults to ``Level/error`` so
    /// client apps see only real problems unless they opt in to more detail.
    nonisolated(unsafe) public static var level: Level = .error

    private static let subsystem = "com.youversion.platform-sdk"

    public static func debug(
        _ message: @autoclosure () -> String,
        category: String = "default"
    ) {
        log(level: .debug, category: category, message: message)
    }

    public static func info(
        _ message: @autoclosure () -> String,
        category: String = "default"
    ) {
        log(level: .info, category: category, message: message)
    }

    public static func notice(
        _ message: @autoclosure () -> String,
        category: String = "default"
    ) {
        log(level: .notice, category: category, message: message)
    }

    public static func error(
        _ message: @autoclosure () -> String,
        category: String = "default"
    ) {
        log(level: .error, category: category, message: message)
    }

    public static func fault(
        _ message: @autoclosure () -> String,
        category: String = "default"
    ) {
        log(level: .fault, category: category, message: message)
    }

    private static func log(level: Level, category: String, message: () -> String) {
        guard level >= Self.level else {
            return
        }
        let text = message()
        #if canImport(os)
        let logger = Logger(subsystem: subsystem, category: category)
        switch level {
        case .debug:
            logger.debug("\(text, privacy: .public)")
        case .info:
            logger.info("\(text, privacy: .public)")
        case .notice:
            logger.notice("\(text, privacy: .public)")
        case .error:
            logger.error("\(text, privacy: .public)")
        case .fault:
            logger.fault("\(text, privacy: .public)")
        case .off:
            break
        }
        #else
        print("[YouVersionPlatform][\(level)][\(category)] \(text)")
        #endif
    }
}
