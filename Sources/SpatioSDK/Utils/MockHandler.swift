import Foundation

/// Protocol for capabilities supporting mock data
public protocol MockDataProvider {
    /// Returns mock data for the capability
    /// - Parameter params: The parameters passed to the capability
    /// - Returns: Mock JSON response
    func provideMockData(for params: [String: String]) -> String
}

/// Handler for mock data in testing environments
public class MockHandler {
    /// Singleton instance
    public static let shared = MockHandler()
    
    /// Whether mock data is enabled globally
    public var isMockEnabled: Bool {
        return SpatioSDK.shared.configuration().useMockData
    }
    
    private init() {}
    
    /// Get mock data for a capability if mocking is enabled
    /// - Parameters:
    ///   - capability: The capability to get mock data for
    ///   - params: The parameters passed to the capability
    /// - Returns: Mock data if mocking is enabled, nil otherwise
    public func getMockData(for capability: MockDataProvider, params: [String: String]) -> String? {
        guard isMockEnabled else {
            return nil
        }
        
        Logger.shared.info("Using mock data for \(type(of: capability))")
        return capability.provideMockData(for: params)
    }
    
    /// Helper method to load mock data from a JSON file
    /// - Parameters:
    ///   - filename: The name of the mock data file
    ///   - bundle: The bundle containing the mock data
    /// - Returns: Mock data JSON string
    public func loadMockData(from filename: String, bundle: Bundle = .main) -> String {
        do {
            let url = bundle.url(forResource: filename, withExtension: "json")
            if let url = url {
                Logger.shared.debug("Loading mock data from \(url.path)")
                return try String(contentsOf: url, encoding: .utf8)
            }
            
            // Look in Resources/MockData directory
            let mockDataURL = bundle.url(forResource: "MockData/\(filename)", withExtension: "json")
            if let mockDataURL = mockDataURL {
                Logger.shared.debug("Loading mock data from \(mockDataURL.path)")
                return try String(contentsOf: mockDataURL, encoding: .utf8)
            }
            
            Logger.shared.warning("Mock data file \(filename).json not found")
        } catch {
            // If we can't load mock data, return an empty JSON object
            Logger.shared.error("Error loading mock data: \(error.localizedDescription)")
        }
        
        return "{}"
    }
    
    /// Generate mock response based on API parameters and values
    /// - Parameters:
    ///   - request: The API request configuration
    ///   - params: The parameters passed to the capability
    /// - Returns: Generated mock JSON response
    public func generateMockResponse(for request: APIRequest, params: [String: String]) -> String {
        Logger.shared.debug("Generating mock response for \(request.baseURL)\(request.endpoint)")
        
        let response: [String: Any] = [
            "meta": [
                "mock": true,
                "endpoint": request.endpoint,
                "method": request.method
            ],
            "params": params,
            "result": [
                "message": "This is mock data generated by SpatioSDK",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            Logger.shared.error("Failed to generate mock response: \(error.localizedDescription)")
            return "{\"error\": \"Failed to generate mock response\"}"
        }
    }
} 