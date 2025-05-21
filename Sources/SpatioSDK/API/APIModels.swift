import Foundation

/// Location of a parameter in an API request
public enum ParameterLocation: String, Codable {
    case query = "query"
    case path = "path"
    case header = "header"
    case body = "body"
}

/// Defines a parameter for an API request
public struct APIParameter {
    /// The name of the parameter
    public let name: String
    
    /// The expected type of the parameter (string, integer, boolean, etc.)
    public let type: String
    
    /// Whether the parameter is required
    public let required: Bool
    
    /// Location of the parameter in the request
    public let location: ParameterLocation
    
    /// Default value for the parameter if not provided
    public let defaultValue: String?
    
    /// Description of the parameter
    public let description: String?
    
    public init(
        name: String,
        type: String,
        required: Bool = false,
        location: ParameterLocation = .query,
        defaultValue: String? = nil,
        description: String? = nil
    ) {
        self.name = name
        self.type = type
        self.required = required
        self.location = location
        self.defaultValue = defaultValue
        self.description = description
    }
}

/// Defines an API request configuration
public struct APIRequest {
    /// Base URL for the API
    public let baseURL: String
    
    /// Endpoint path (may include path parameters)
    public let endpoint: String
    
    /// HTTP method (GET, POST, etc.)
    public let method: String
    
    /// Parameters for the request
    public let parameters: [APIParameter]
    
    public init(
        baseURL: String,
        endpoint: String,
        method: String = "GET",
        parameters: [APIParameter] = []
    ) {
        self.baseURL = baseURL
        self.endpoint = endpoint
        self.method = method
        self.parameters = parameters
    }
} 