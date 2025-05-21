import Foundation

/// Authentication type supported by remote capabilities
public enum AuthType: String, Codable {
    case apiKey = "api_key"
    case oauth2 = "oauth2"
    case basic = "basic"
    case none = "none"
}

/// Location where authentication should be applied in requests
public enum AuthLocation: String, Codable {
    case header = "header"
    case query = "query"
    case body = "body"
}

/// Authentication configuration for remote capabilities
public struct AuthConfig: Codable {
    /// Type of authentication
    public let type: AuthType
    
    /// Name of the auth parameter (e.g., "Authorization", "api_key", etc.)
    public let parameterName: String
    
    /// Where to place the auth parameter in the request
    public let location: AuthLocation
    
    /// Optional prefix for the auth value (e.g., "Bearer " for OAuth tokens)
    public let valuePrefix: String?
    
    /// Environment variable name used to retrieve the auth value
    public let envVariable: String
    
    public init(
        type: AuthType,
        parameterName: String,
        location: AuthLocation,
        valuePrefix: String? = nil,
        envVariable: String
    ) {
        self.type = type
        self.parameterName = parameterName
        self.location = location
        self.valuePrefix = valuePrefix
        self.envVariable = envVariable
    }
}

/// Hierarchical authentication configuration for capabilities
public class AuthManager {
    /// Singleton instance
    public static let shared = AuthManager()
    
    /// Organization-level auth configurations
    private var orgConfigs: [String: AuthConfig] = [:]
    
    /// Group-level auth configurations
    private var groupConfigs: [String: [String: AuthConfig]] = [:]
    
    /// Capability-level auth configurations
    private var capabilityConfigs: [String: [String: [String: AuthConfig]]] = [:]
    
    private init() {}
    
    /// Set authentication configuration at the organization level
    public func setAuthConfig(for organization: String, config: AuthConfig) {
        orgConfigs[organization] = config
    }
    
    /// Set authentication configuration at the group level
    public func setAuthConfig(for organization: String, group: String, config: AuthConfig) {
        if groupConfigs[organization] == nil {
            groupConfigs[organization] = [:]
        }
        groupConfigs[organization]?[group] = config
    }
    
    /// Set authentication configuration at the capability level
    public func setAuthConfig(for organization: String, group: String, capability: String, config: AuthConfig) {
        if capabilityConfigs[organization] == nil {
            capabilityConfigs[organization] = [:]
        }
        if capabilityConfigs[organization]?[group] == nil {
            capabilityConfigs[organization]?[group] = [:]
        }
        capabilityConfigs[organization]?[group]?[capability] = config
    }
    
    /// Get the most specific auth configuration for a capability
    public func getAuthConfig(for organization: String, group: String, capability: String) -> AuthConfig? {
        // Check capability-level config
        if let capConfig = capabilityConfigs[organization]?[group]?[capability] {
            return capConfig
        }
        
        // Check group-level config
        if let groupConfig = groupConfigs[organization]?[group] {
            return groupConfig
        }
        
        // Check organization-level config
        return orgConfigs[organization]
    }
    
    /// Gets auth token using the appropriate configuration
    public func getAuthToken(for organization: String, group: String, capability: String) throws -> (name: String, value: String, location: AuthLocation) {
        guard let config = getAuthConfig(for: organization, group: group, capability: capability) else {
            throw NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authentication configuration found"])
        }
        
        guard let token = ProcessInfo.processInfo.environment[config.envVariable] else {
            throw NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication token not found in environment variable \(config.envVariable)"])
        }
        
        let authValue = config.valuePrefix != nil ? "\(config.valuePrefix!)\(token)" : token
        
        return (name: config.parameterName, value: authValue, location: config.location)
    }
} 