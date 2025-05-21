import Foundation

/// Defines where a parameter is located in an API request
public enum ParameterLocation: String, Codable {
    case query
    case header
    case body
    case path
}

/// Represents a parameter used in an API request
public struct APIParameter: Codable {
    public let name: String
    public let type: String
    public let required: Bool
    public let location: ParameterLocation
    public let defaultValue: String?
    public let description: String
    public let subParameters: [APIParameter]?
    
    public init(name: String, type: String, required: Bool, location: ParameterLocation, 
                defaultValue: String? = nil, description: String, subParameters: [APIParameter]? = nil) {
        self.name = name
        self.type = type
        self.required = required
        self.location = location
        self.defaultValue = defaultValue
        self.description = description
        self.subParameters = subParameters
    }
}

/// Represents an API request configuration
public struct APIRequest: Codable {
    public let baseURL: String
    public let endpoint: String
    public let method: String
    public let parameters: [APIParameter]
    
    public init(baseURL: String, endpoint: String, method: String, parameters: [APIParameter]) {
        self.baseURL = baseURL
        self.endpoint = endpoint
        self.method = method
        self.parameters = parameters
    }
    
    /// Build the URL for the request, including path parameters
    public func buildURL(with params: [String: String]) -> URL? {
        var endpointWithParams = endpoint
        
        // Replace path parameters in endpoint
        for param in parameters where param.location == .path && params[param.name] != nil {
            let placeholder = "{\(param.name)}"
            endpointWithParams = endpointWithParams.replacingOccurrences(of: placeholder, with: params[param.name]!)
        }
        
        // Build URL components
        guard var components = URLComponents(string: baseURL + endpointWithParams) else {
            return nil
        }
        
        // Add query parameters
        var queryItems: [URLQueryItem] = []
        for param in parameters where param.location == .query && params[param.name] != nil {
            queryItems.append(URLQueryItem(name: param.name, value: params[param.name]))
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        return components.url
    }
    
    /// Create request headers including any header parameters
    public func createHeaders(with params: [String: String]) -> [String: String] {
        var headers = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        
        // Add header parameters
        for param in parameters where param.location == .header && params[param.name] != nil {
            headers[param.name] = params[param.name]
        }
        
        // Add authorization if provided
        if let authToken = params["auth_token"] {
            headers["Authorization"] = "Bearer \(authToken)"
        }
        
        return headers
    }
    
    /// Create request body from body parameters
    public func createBody(with params: [String: String]) -> [String: Any]? {
        var bodyParams: [String: Any] = [:]
        var hasBodyParams = false
        
        for param in parameters where param.location == .body && params[param.name] != nil {
            bodyParams[param.name] = convertParamValue(param: param, value: params[param.name]!)
            hasBodyParams = true
        }
        
        return hasBodyParams ? bodyParams : nil
    }
    
    /// Convert parameter value to appropriate type
    private func convertParamValue(param: APIParameter, value: String) -> Any {
        switch param.type {
        case "integer":
            return Int(value) ?? 0
        case "boolean":
            return ["true", "1", "yes"].contains(value.lowercased())
        default:
            return value
        }
    }
}

/// Represents the result of a capability execution
public struct CapabilityResult: Codable {
    public let output: String
    public let success: Bool
    public let timestamp: Date
    public let executionTime: TimeInterval
    
    public init(output: String, success: Bool, timestamp: Date, executionTime: TimeInterval) {
        self.output = output
        self.success = success
        self.timestamp = timestamp
        self.executionTime = executionTime
    }
    
    /// Convert the result to JSON
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

/// Represents a remote capability
public protocol RemoteCapability {
    /// Configure the API request for this capability
    func configureRequest() -> APIRequest
    
    /// Execute the capability
    func execute(params: [String: String]) async throws -> CapabilityResult
    
    /// Get mock data for testing
    func getMockData() -> String
}

/// Base class for remote capabilities
open class BaseRemoteCapability: RemoteCapability {
    public let request: APIRequest
    
    public init() {
        self.request = configureRequest()
    }
    
    open func configureRequest() -> APIRequest {
        fatalError("Subclasses must implement configureRequest()")
    }
    
    open func getMockData() -> String {
        return "{}"
    }
    
    public func execute(params: [String: String]) async throws -> CapabilityResult {
        let startTime = Date()
        
        do {
            // Build the URL
            guard let url = request.buildURL(with: params) else {
                throw NSError(domain: "com.spatio.capability", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to build URL"])
            }
            
            // Get headers
            let headers = request.createHeaders(with: params)
            
            // Create URLRequest
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = request.method
            
            // Add headers
            for (key, value) in headers {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
            
            // Add body if present
            if let body = request.createBody(with: params) {
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            }
            
            // Start a URL session task
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            let outputString = String(data: data, encoding: .utf8) ?? "{}"
            
            return CapabilityResult(
                output: outputString,
                success: true,
                timestamp: Date(),
                executionTime: Date().timeIntervalSince(startTime)
            )
        } catch {
            // For development/test, return mock data on failure
            if params["use_mock_data"] == "true" {
                return CapabilityResult(
                    output: getMockData(),
                    success: true,
                    timestamp: Date(),
                    executionTime: Date().timeIntervalSince(startTime)
                )
            }
            
            // Otherwise, return error
            return CapabilityResult(
                output: "{\"error\": \"\(error.localizedDescription)\"}",
                success: false,
                timestamp: Date(),
                executionTime: Date().timeIntervalSince(startTime)
            )
        }
    }
} 