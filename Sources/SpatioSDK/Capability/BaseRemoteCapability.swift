import Foundation

/// Base class for remote capabilities interacting with APIs
open class BaseRemoteCapability {
    /// Organization identifier from capability.json
    public var organization: String = ""
    
    /// Group identifier from capability.json
    public var group: String = ""
    
    /// Capability identifier from capability.json
    public var capability: String = ""
    
    /// API request configuration for this capability
    public var request: APIRequest {
        return configureRequest()
    }
    
    public init(organization: String = "", group: String = "", capability: String = "") {
        self.organization = organization
        self.group = group
        self.capability = capability
    }
    
    /// Configure the API request for this capability
    /// Override this method to define your API endpoint, parameters, etc.
    open func configureRequest() -> APIRequest {
        fatalError("Subclasses must override configureRequest()")
    }
    
    /// Execute the capability with the provided parameters
    /// - Parameter params: Dictionary of parameter values
    /// - Returns: JSON response string
    public func execute(params: [String: String]) async throws -> String {
        // Create URL with path parameters and query parameters
        let url = try constructURL(from: request, with: params)
        
        // Create URL request with appropriate method
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        
        // Add content-type for all requests
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization if configured
        try addAuthentication(to: &urlRequest, with: params)
        
        // Add body parameters if applicable
        if request.method != "GET" {
            let bodyParams = request.parameters.filter { $0.location == .body }
            if !bodyParams.isEmpty {
                var bodyData: [String: Any] = [:]
                for param in bodyParams {
                    if let value = params[param.name] {
                        bodyData[param.name] = value
                    }
                }
                if !bodyData.isEmpty {
                    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: bodyData)
                }
            }
        }
        
        // Make the API request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "APIRequest", code: (response as? HTTPURLResponse)?.statusCode ?? 500,
                         userInfo: [NSLocalizedDescriptionKey: errorResponse])
        }
        
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    /// Adds authentication to the request based on configuration
    private func addAuthentication(to request: inout URLRequest, with params: [String: String]) throws {
        if !organization.isEmpty && !group.isEmpty && !capability.isEmpty {
            // Use the AuthManager to get configured authentication
            let auth = try AuthManager.shared.getAuthToken(for: organization, group: group, capability: capability)
            
            switch auth.location {
            case .header:
                request.addValue(auth.value, forHTTPHeaderField: auth.name)
            case .query:
                // Query parameters are handled during URL construction
                // This is for reference only as auth should already be in params
                break
            case .body:
                // Body parameters would be added with other body params
                // This is for reference only as auth should already be in params
                break
            }
        } else if let authToken = params["auth_token"] {
            // Fallback to simple auth token from params if identifiers not set
            request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
    }
    
    /// Constructs a URL from the API request and parameters
    private func constructURL(from request: APIRequest, with params: [String: String]) throws -> URL {
        var endpoint = request.endpoint
        
        // Replace path parameters
        let pathParams = request.parameters.filter { $0.location == .path }
        for param in pathParams {
            if let value = params[param.name] ?? param.defaultValue {
                endpoint = endpoint.replacingOccurrences(of: "{\(param.name)}", with: value)
            }
        }
        
        // Create base URL with endpoint
        var urlComponents = URLComponents(string: request.baseURL + endpoint)
        
        // Add query parameters
        let queryParams = request.parameters.filter { $0.location == .query }
        if !queryParams.isEmpty {
            var queryItems: [URLQueryItem] = []
            
            for param in queryParams {
                if let value = params[param.name] ?? param.defaultValue {
                    queryItems.append(URLQueryItem(name: param.name, value: value))
                }
            }
            
            // Add auth query parameter if configured
            if !organization.isEmpty && !group.isEmpty && !capability.isEmpty {
                if let config = AuthManager.shared.getAuthConfig(for: organization, group: group, capability: capability),
                   config.location == .query {
                    if let token = ProcessInfo.processInfo.environment[config.envVariable] {
                        let authValue = config.valuePrefix != nil ? "\(config.valuePrefix!)\(token)" : token
                        queryItems.append(URLQueryItem(name: config.parameterName, value: authValue))
                    }
                }
            }
            
            if !queryItems.isEmpty {
                urlComponents?.queryItems = queryItems
            }
        }
        
        guard let url = urlComponents?.url else {
            throw NSError(domain: "APIRequest", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL components"])
        }
        
        return url
    }
} 