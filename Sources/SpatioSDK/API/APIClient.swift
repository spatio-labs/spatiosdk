import Foundation

/// Client for making API requests with appropriate authentication and parameter handling
public class APIClient {
    /// Singleton instance
    public static let shared = APIClient()
    
    /// URLSession for making network requests
    private let session: URLSession
    
    /// Initializes the API client with the specified URLSession
    /// - Parameter session: The URLSession to use for network requests. Defaults to the shared session.
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Executes an API request with the specified parameters and authentication
    /// - Parameters:
    ///   - request: The API request configuration
    ///   - params: Dictionary of parameter names and values
    ///   - organization: Organization identifier for authentication
    ///   - parentOrganization: Parent organization identifier for authentication
    ///   - capability: Capability identifier for authentication
    /// - Returns: The response data from the API
    public func execute(
        request: APIRequest,
        params: [String: String],
        organization: String,
        parentOrganization: String,
        capability: String
    ) async throws -> Data {
        Logger.shared.info("Executing API request: \(request.method) \(request.baseURL)\(request.endpoint)")
        Logger.shared.debug("Request parameters: \(params)")
        
        // Build URL with path parameters and query parameters
        var urlString = request.baseURL
        if !urlString.hasSuffix("/") && !request.endpoint.hasPrefix("/") {
            urlString += "/"
        }
        urlString += try replacedPathParameters(in: request.endpoint, with: params)
        
        guard var urlComponents = URLComponents(string: urlString) else {
            Logger.shared.error("Invalid URL: \(urlString)")
            throw NSError(domain: "APIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])
        }
        
        // Add query parameters
        let queryParams = request.parameters.filter { $0.location == .query }
        if !queryParams.isEmpty {
            var queryItems: [URLQueryItem] = []
            for param in queryParams {
                if let value = params[param.name] {
                    queryItems.append(URLQueryItem(name: param.name, value: value))
                } else if let defaultValue = param.defaultValue {
                    queryItems.append(URLQueryItem(name: param.name, value: defaultValue))
                } else if param.required {
                    Logger.shared.error("Missing required query parameter: \(param.name)")
                    throw NSError(domain: "APIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing required query parameter: \(param.name)"])
                }
            }
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            Logger.shared.error("Could not create URL from components")
            throw NSError(domain: "APIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Could not create URL from components"])
        }
        
        Logger.shared.debug("Request URL: \(url.absoluteString)")
        
        // Create URLRequest
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        
        // Add header parameters
        let headerParams = request.parameters.filter { $0.location == .header }
        for param in headerParams {
            if let value = params[param.name] {
                urlRequest.setValue(value, forHTTPHeaderField: param.name)
            } else if let defaultValue = param.defaultValue {
                urlRequest.setValue(defaultValue, forHTTPHeaderField: param.name)
            } else if param.required {
                Logger.shared.error("Missing required header parameter: \(param.name)")
                throw NSError(domain: "APIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing required header parameter: \(param.name)"])
            }
        }
        
        // Add body parameters if needed
        let bodyParams = request.parameters.filter { $0.location == .body }
        if !bodyParams.isEmpty {
            var bodyDict: [String: Any] = [:]
            for param in bodyParams {
                if let value = params[param.name] {
                    bodyDict[param.name] = value
                } else if let defaultValue = param.defaultValue {
                    bodyDict[param.name] = defaultValue
                } else if param.required {
                    Logger.shared.error("Missing required body parameter: \(param.name)")
                    throw NSError(domain: "APIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing required body parameter: \(param.name)"])
                }
            }
            
            if !bodyDict.isEmpty {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)
                Logger.shared.debug("Request body: \(bodyDict)")
            }
        }
        
        // Add authentication
        do {
            let authToken = try AuthManager.shared.getAuthToken(for: organization, parentOrganization: parentOrganization, capability: capability)
            
            switch authToken.location {
            case .header:
                urlRequest.setValue(authToken.value, forHTTPHeaderField: authToken.name)
                Logger.shared.debug("Added authentication header: \(authToken.name)")
            case .query:
                if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                    var items = components.queryItems ?? []
                    items.append(URLQueryItem(name: authToken.name, value: authToken.value))
                    components.queryItems = items
                    if let newURL = components.url {
                        urlRequest.url = newURL
                        Logger.shared.debug("Added authentication query parameter: \(authToken.name)")
                    }
                }
            case .body:
                if urlRequest.httpBody != nil {
                    // If body exists, need to modify JSON
                    if let bodyData = urlRequest.httpBody,
                       var bodyDict = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
                        bodyDict[authToken.name] = authToken.value
                        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)
                        Logger.shared.debug("Added authentication to existing body: \(authToken.name)")
                    }
                } else {
                    // Create body with just auth token
                    let bodyDict = [authToken.name: authToken.value]
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)
                    Logger.shared.debug("Created body with authentication: \(authToken.name)")
                }
            }
        } catch {
            // If configured to not require auth or auth is not available, just proceed
            Logger.shared.warning("Failed to apply authentication: \(error.localizedDescription)")
        }
        
        // Execute the request
        Logger.shared.debug("Sending request...")
        let (data, response) = try await session.data(for: urlRequest)
        
        // Validate the response
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.shared.error("Invalid response type")
            throw NSError(domain: "APIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
        }
        
        Logger.shared.debug("Received response with status code: \(httpResponse.statusCode)")
        
        // Check for successful status code (200-299)
        guard (200...299).contains(httpResponse.statusCode) else {
            let responseString = String(data: data, encoding: .utf8) ?? "No response data"
            Logger.shared.error("HTTP Error: \(httpResponse.statusCode), Response: \(responseString)")
            throw NSError(domain: "APIClient", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)",
                "response_data": responseString
            ])
        }
        
        Logger.shared.info("Request successful")
        if Logger.shared.level >= .debug {
            let responseString = String(data: data, encoding: .utf8) ?? "Non-text response"
            Logger.shared.debug("Response data: \(responseString)")
        }
        
        return data
    }
    
    /// Replaces path parameters in the endpoint path with values from the params dictionary
    /// - Parameters:
    ///   - endpoint: The endpoint path with potential path parameters
    ///   - params: Dictionary of parameter names and values
    /// - Returns: The endpoint with path parameters replaced
    private func replacedPathParameters(in endpoint: String, with params: [String: String]) throws -> String {
        var result = endpoint
        
        // Look for {parameter} patterns in the endpoint
        let pathParamRegex = try? NSRegularExpression(pattern: "\\{([^}]+)\\}", options: [])
        let matches = pathParamRegex?.matches(in: endpoint, options: [], range: NSRange(location: 0, length: endpoint.utf16.count)) ?? []
        
        // Replace each parameter with its value from the params dictionary
        for match in matches.reversed() {
            guard let paramRange = Range(match.range(at: 1), in: endpoint) else { continue }
            
            let paramName = String(endpoint[paramRange])
            if let value = params[paramName] {
                result = result.replacingOccurrences(of: "{\(paramName)}", with: value)
                Logger.shared.debug("Replaced path parameter \(paramName) with value \(value)")
            } else {
                Logger.shared.error("Missing required path parameter: \(paramName)")
                throw NSError(domain: "APIClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "Missing required path parameter: \(paramName)"])
            }
        }
        
        return result
    }
    
    // For backward compatibility
    public func execute(
        request: APIRequest,
        params: [String: String],
        organization: String,
        capability: String
    ) async throws -> Data {
        return try await execute(
            request: request,
            params: params,
            organization: organization,
            parentOrganization: organization,
            capability: capability
        )
    }
} 