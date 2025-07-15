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
    
    /// OAuth scopes (optional)
    public let scopes: [String]?
    
    public init(
        type: AuthType,
        parameterName: String,
        location: AuthLocation,
        valuePrefix: String? = nil,
        envVariable: String,
        scopes: [String]? = nil
    ) {
        self.type = type
        self.parameterName = parameterName
        self.location = location
        self.valuePrefix = valuePrefix
        self.envVariable = envVariable
        self.scopes = scopes
    }
}

/// Hierarchical authentication configuration for capabilities
public class AuthManager {
    /// Singleton instance
    public static let shared = AuthManager()
    
    /// Organization-level auth configurations
    private var orgConfigs: [String: AuthConfig] = [:]
    
    /// Child organization auth configurations
    private var childOrgConfigs: [String: [String: AuthConfig]] = [:]
    
    /// Capability-level auth configurations
    private var capabilityConfigs: [String: [String: AuthConfig]] = [:]
    
    /// Parent-child organization relationships
    private var orgRelationships: [String: String] = [:]
    
    private init() {}
    
    /// Set authentication configuration at the organization level
    public func setAuthConfig(for organization: String, config: AuthConfig) {
        orgConfigs[organization] = config
    }
    
    /// Set authentication configuration for a child organization
    public func setAuthConfig(for childOrg: String, parentOrganization: String, config: AuthConfig) {
        // Store the parent-child relationship
        orgRelationships[childOrg] = parentOrganization
        
        if childOrgConfigs[parentOrganization] == nil {
            childOrgConfigs[parentOrganization] = [:]
        }
        childOrgConfigs[parentOrganization]?[childOrg] = config
    }
    
    /// Set authentication configuration at the capability level
    public func setAuthConfig(for organization: String, capability: String, config: AuthConfig) {
        if capabilityConfigs[organization] == nil {
            capabilityConfigs[organization] = [:]
        }
        capabilityConfigs[organization]?[capability] = config
    }
    
    /// Get the most specific auth configuration for a capability
    public func getAuthConfig(for organization: String, parentOrganization: String = "", capability: String) -> AuthConfig? {
        // Check capability-level config
        if let capConfig = capabilityConfigs[organization]?[capability] {
            return capConfig
        }
        
        // Check organization-level config
        if let orgConfig = orgConfigs[organization] {
            return orgConfig
        }
        
        // Check parent organization config if available
        if !parentOrganization.isEmpty {
            if let parentConfig = childOrgConfigs[parentOrganization]?[organization] {
                return parentConfig
            }
            
            // Try parent's organization config
            return orgConfigs[parentOrganization]
        }
        
        // Check if this organization has a parent we know about
        if let parent = orgRelationships[organization] {
            if let parentChildConfig = childOrgConfigs[parent]?[organization] {
                return parentChildConfig
            }
            
            // Try parent's organization config
            return orgConfigs[parent]
        }
        
        return nil
    }
    
    
    /// Gets auth token using the appropriate configuration
    public func getAuthToken(for organization: String, parentOrganization: String = "", capability: String) throws -> (name: String, value: String, location: AuthLocation) {
        guard let config = getAuthConfig(for: organization, parentOrganization: parentOrganization, capability: capability) else {
            let orgPath = parentOrganization.isEmpty ? organization : "\(parentOrganization)/\(organization)"
            throw NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authentication configuration found for \(orgPath)/\(capability)"])
        }
        
        guard let token = ProcessInfo.processInfo.environment[config.envVariable] else {
            throw NSError(domain: "AuthManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication token not found in environment variable \(config.envVariable)"])
        }
        
        let authValue = config.valuePrefix != nil ? "\(config.valuePrefix!)\(token)" : token
        
        return (name: config.parameterName, value: authValue, location: config.location)
    }
    
} 