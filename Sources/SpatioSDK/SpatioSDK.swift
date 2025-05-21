// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

/// SpatioSDK is the main entry point for using the SDK capabilities.
public struct SpatioSDK {
    /// The shared singleton instance of the SDK.
    public static let shared = SpatioSDK()
    
    /// The version of the SDK.
    public static let version = "1.0.0"
    
    /// Private initializer to enforce the use of the shared instance.
    private init() {}
    
    /// Initializes the SDK with the specified configuration.
    /// - Parameter config: The configuration for the SDK.
    public func configure(with config: SpatioConfig) {
        SpatioConfig.current = config
    }
    
    /// Returns the current configuration of the SDK.
    /// - Returns: The current configuration.
    public func configuration() -> SpatioConfig {
        return SpatioConfig.current
    }
    
    /// Resets the SDK to its default configuration.
    public func reset() {
        SpatioConfig.current = SpatioConfig.default
    }
}

/// Configuration for the SpatioSDK.
public struct SpatioConfig {
    /// The default configuration for the SDK.
    public static let `default` = SpatioConfig()
    
    /// The current configuration for the SDK.
    internal static var current = SpatioConfig.default
    
    /// The logging level for the SDK.
    public var loggingLevel: LoggingLevel
    
    /// Whether to use mock data for testing.
    public var useMockData: Bool
    
    /// The base URL for API requests.
    public var baseURL: URL?
    
    /// Initializes a new configuration with the specified parameters.
    /// - Parameters:
    ///   - loggingLevel: The logging level for the SDK. Defaults to `.info`.
    ///   - useMockData: Whether to use mock data for testing. Defaults to `false`.
    ///   - baseURL: The base URL for API requests. Defaults to `nil`.
    public init(loggingLevel: LoggingLevel = .info, useMockData: Bool = false, baseURL: URL? = nil) {
        self.loggingLevel = loggingLevel
        self.useMockData = useMockData
        self.baseURL = baseURL
    }
}

/// Logging levels for the SDK.
public enum LoggingLevel: Int, Comparable {
    case none = 0
    case error = 1
    case warning = 2
    case info = 3
    case debug = 4
    
    public static func < (lhs: LoggingLevel, rhs: LoggingLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
