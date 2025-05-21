import Foundation

/// Logging utility for SpatioSDK
public class Logger {
    /// Singleton instance
    public static let shared = Logger()
    
    /// Current logging level, determined by the SDK configuration
    public var level: LoggingLevel {
        return SpatioSDK.shared.configuration().loggingLevel
    }
    
    private init() {}
    
    /// Log a message at the debug level
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log occurred
    ///   - function: The function where the log occurred
    ///   - line: The line where the log occurred
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    /// Log a message at the info level
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log occurred
    ///   - function: The function where the log occurred
    ///   - line: The line where the log occurred
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    /// Log a message at the warning level
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log occurred
    ///   - function: The function where the log occurred
    ///   - line: The line where the log occurred
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }
    
    /// Log a message at the error level
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file where the log occurred
    ///   - function: The function where the log occurred
    ///   - line: The line where the log occurred
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, file: file, function: function, line: line)
    }
    
    /// Log a message if the configured log level is sufficient
    /// - Parameters:
    ///   - level: The level of the message
    ///   - message: The message to log
    ///   - file: The file where the log occurred
    ///   - function: The function where the log occurred
    ///   - line: The line where the log occurred
    private func log(level messageLevel: LoggingLevel, message: String, file: String, function: String, line: Int) {
        if self.level >= messageLevel {
            let filename = URL(fileURLWithPath: file).lastPathComponent
            let logMessage = "[\(levelString(for: messageLevel))] [\(filename):\(line)] \(function) - \(message)"
            print(logMessage)
        }
    }
    
    /// Get a string representation of a log level
    /// - Parameter level: The log level
    /// - Returns: A string representation of the log level
    private func levelString(for level: LoggingLevel) -> String {
        switch level {
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .warning:
            return "WARNING"
        case .error:
            return "ERROR"
        case .none:
            return "NONE"
        }
    }
} 