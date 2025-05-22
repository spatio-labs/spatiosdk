import Foundation

/// Base class for remote capabilities interacting with APIs
open class BaseRemoteCapability: MockDataProvider {
    /// Organization identifier from capability.json
    public var organization: String = ""
    
    /// Parent organization identifier (optional)
    public var parentOrganization: String = ""
    
    /// Capability identifier from capability.json
    public var capability: String = ""
    
    /// API request configuration for this capability
    public var request: APIRequest {
        return configureRequest()
    }
    
    public init(organization: String = "", parentOrganization: String = "", capability: String = "") {
        self.organization = organization
        self.parentOrganization = parentOrganization
        self.capability = capability
        Logger.shared.debug("Initialized \(type(of: self)) with org: \(organization), parent: \(parentOrganization), capability: \(capability)")
    }
    
    // For backward compatibility
    public convenience init(organization: String = "", group: String = "", capability: String = "") {
        self.init(organization: group.isEmpty ? organization : group, 
                 parentOrganization: group.isEmpty ? "" : organization, 
                 capability: capability)
    }
    
    /// Configure the API request for this capability
    /// Override this method to define your API endpoint, parameters, etc.
    open func configureRequest() -> APIRequest {
        fatalError("Subclasses must override configureRequest()")
    }
    
    /// Provide mock data for testing
    /// Override this method to provide custom mock data
    open func provideMockData(for params: [String: String]) -> String {
        Logger.shared.debug("Generating generic mock data for \(type(of: self))")
        return MockHandler.shared.generateMockResponse(for: request, params: params)
    }
    
    /// Execute the capability with the provided parameters
    /// - Parameter params: Dictionary of parameter values
    /// - Returns: JSON response string
    public func execute(params: [String: String]) async throws -> String {
        Logger.shared.info("Executing capability \(type(of: self))")
        Logger.shared.debug("Parameters: \(params)")
        
        // Check if mock mode is enabled
        if let mockData = MockHandler.shared.getMockData(for: self, params: params) {
            Logger.shared.info("Using mock data for \(type(of: self))")
            return mockData
        }
        
        // Get actual API data
        Logger.shared.info("Executing live API request for \(type(of: self))")
        return try await executeAPIRequest(with: params)
    }
    
    /// Execute the actual API request
    /// - Parameter params: Dictionary of parameter values
    /// - Returns: JSON response string
    private func executeAPIRequest(with params: [String: String]) async throws -> String {
        Logger.shared.debug("Making API request to \(request.baseURL)\(request.endpoint)")
        
        let data = try await APIClient.shared.execute(
            request: request,
            params: params,
            organization: organization,
            parentOrganization: parentOrganization,
            capability: capability
        )
        
        let responseString = String(data: data, encoding: .utf8) ?? "{}"
        Logger.shared.debug("Received API response with \(data.count) bytes")
        return responseString
    }
    
    /// Adds authentication to the request based on configuration
    private func addAuthentication(to request: inout URLRequest, with params: [String: String]) throws {
        if !organization.isEmpty && !capability.isEmpty {
            // Use the AuthManager to get configured authentication
            let orgPath = parentOrganization.isEmpty ? organization : "\(parentOrganization)/\(organization)"
            Logger.shared.debug("Getting auth token for \(orgPath)/\(capability)")
            
            let auth = try AuthManager.shared.getAuthToken(
                for: organization,
                parentOrganization: parentOrganization,
                capability: capability
            )
            
            switch auth.location {
            case .header:
                request.addValue(auth.value, forHTTPHeaderField: auth.name)
                Logger.shared.debug("Added auth header: \(auth.name)")
            case .query:
                // Query parameters are handled during URL construction
                Logger.shared.debug("Auth will be added as query parameter: \(auth.name)")
                break
            case .body:
                // Body parameters would be added with other body params
                Logger.shared.debug("Auth will be added to request body: \(auth.name)")
                break
            }
        } else if let authToken = params["auth_token"] {
            // Fallback to simple auth token from params if identifiers not set
            request.addValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            Logger.shared.debug("Using fallback auth token from params")
        } else {
            Logger.shared.debug("No authentication configured")
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
                Logger.shared.debug("Replaced path parameter \(param.name) with \(value)")
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
                    Logger.shared.debug("Added query parameter \(param.name)=\(value)")
                }
            }
            
            // Add auth query parameter if configured
            if !organization.isEmpty && !capability.isEmpty {
                if let config = AuthManager.shared.getAuthConfig(
                    for: organization,
                    parentOrganization: parentOrganization,
                    capability: capability
                ),
                config.location == .query {
                    if let token = ProcessInfo.processInfo.environment[config.envVariable] {
                        let authValue = config.valuePrefix != nil ? "\(config.valuePrefix!)\(token)" : token
                        queryItems.append(URLQueryItem(name: config.parameterName, value: authValue))
                        Logger.shared.debug("Added auth query parameter \(config.parameterName)")
                    } else {
                        Logger.shared.warning("Auth token not found in environment variable \(config.envVariable)")
                    }
                }
            }
            
            if !queryItems.isEmpty {
                urlComponents?.queryItems = queryItems
            }
        }
        
        guard let url = urlComponents?.url else {
            Logger.shared.error("Invalid URL components for \(request.baseURL + endpoint)")
            throw NSError(domain: "APIRequest", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL components"])
        }
        
        Logger.shared.debug("Constructed URL: \(url.absoluteString)")
        return url
    }
} 