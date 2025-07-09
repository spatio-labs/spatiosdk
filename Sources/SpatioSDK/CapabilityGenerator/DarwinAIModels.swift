import Foundation

// MARK: - Darwin AI Compatible Models
// These models match the structure expected by Darwin AI's CapabilityMetadata

/// Darwin AI compatible capability metadata structure
public struct DarwinCapabilityMetadata: Codable {
    public let type: String
    public let name: String
    public let description: String
    public let entry_point: String
    public let organization: String
    public let group: String
    public let inputs: [DarwinFunctionParameter]
    public let output: DarwinCapabilityOutput
    public let base_url: String?
    public let auth_type: DarwinAuthenticationType
    public let headers: [DarwinCapabilityHeader]?
    public let auth: DarwinCapabilityAuthInfo?
    
    public init(
        type: String,
        name: String,
        description: String,
        entry_point: String,
        organization: String,
        group: String,
        inputs: [DarwinFunctionParameter],
        output: DarwinCapabilityOutput,
        base_url: String? = nil,
        auth_type: DarwinAuthenticationType = .none,
        headers: [DarwinCapabilityHeader]? = nil,
        auth: DarwinCapabilityAuthInfo? = nil
    ) {
        self.type = type
        self.name = name
        self.description = description
        self.entry_point = entry_point
        self.organization = organization
        self.group = group
        self.inputs = inputs
        self.output = output
        self.base_url = base_url
        self.auth_type = auth_type
        self.headers = headers
        self.auth = auth
    }
}

/// Darwin AI compatible function parameter structure
public struct DarwinFunctionParameter: Codable {
    public let name: String
    public let type: String
    public let required: Bool
    public let defaultValue: String?
    public let description: String
    public let context: [String]?
    
    public init(
        name: String,
        type: String,
        required: Bool,
        defaultValue: String? = nil,
        description: String,
        context: [String]? = nil
    ) {
        self.name = name
        self.type = type
        self.required = required
        self.defaultValue = defaultValue
        self.description = description
        self.context = context
    }
}

/// Darwin AI compatible capability output structure
public struct DarwinCapabilityOutput: Codable {
    public let type: String
    public let description: String?
    public let properties: [String: DarwinOutputProperty]?
    
    public init(
        type: String,
        description: String? = nil,
        properties: [String: DarwinOutputProperty]? = nil
    ) {
        self.type = type
        self.description = description
        self.properties = properties
    }
}

/// Darwin AI compatible output property structure
public struct DarwinOutputProperty: Codable {
    public let type: String
    public let description: String?
    
    public init(type: String, description: String? = nil) {
        self.type = type
        self.description = description
    }
}

/// Darwin AI compatible authentication type enum
public enum DarwinAuthenticationType: String, Codable {
    case none = "None"
    case apiKey = "ApiKey"
    case oauth2 = "OAuth2.0"
    case basic = "Basic"
    case custom = "Custom"
}

/// Darwin AI compatible capability header structure
public struct DarwinCapabilityHeader: Codable {
    public let key: String
    public let value: String
    
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// Darwin AI compatible capability auth info structure
public struct DarwinCapabilityAuthInfo: Codable {
    public let type: String
    public let auth_url: String?
    public let token_url: String?
    public let client_id: String?
    public let scopes: [String]?
    public let env_variable: String?
    
    public init(
        type: String,
        auth_url: String? = nil,
        token_url: String? = nil,
        client_id: String? = nil,
        scopes: [String]? = nil,
        env_variable: String? = nil
    ) {
        self.type = type
        self.auth_url = auth_url
        self.token_url = token_url
        self.client_id = client_id
        self.scopes = scopes
        self.env_variable = env_variable
    }
}

/// Darwin AI compatible organization data structure
public struct DarwinOrganizationData: Codable {
    public let id: String
    public let name: String
    public let description: String
    public let logo: String?
    public let pngLogo: String?
    public let svgLogo: String?
    public let types: [String]
    public let children: [String]?
    public let tags: [String]?
    
    public init(
        id: String,
        name: String,
        description: String,
        logo: String? = nil,
        pngLogo: String? = nil,
        svgLogo: String? = nil,
        types: [String] = ["local"],
        children: [String]? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.logo = logo
        self.pngLogo = pngLogo
        self.svgLogo = svgLogo
        self.types = types
        self.children = children
        self.tags = tags
    }
}

// MARK: - Conversion Extensions

extension DarwinCapabilityMetadata {
    /// Convert to capabilities-store compatible format
    public func toCapabilitiesStoreFormat() -> CapabilitiesStoreCapability {
        let inputs = self.inputs.map { param in
            CapabilitiesStoreInput(
                name: param.name,
                type: param.type,
                required: param.required,
                description: param.description,
                default: param.defaultValue
            )
        }
        
        return CapabilitiesStoreCapability(
            name: self.name,
            description: self.description,
            organization: self.organization,
            type: self.type,
            entry_point: self.entry_point,
            inputs: inputs,
            output: CapabilitiesStoreOutput(
                type: self.output.type,
                description: self.output.description
            ),
            auth: self.auth.map { authInfo in
                CapabilitiesStoreAuth(
                    type: authInfo.type,
                    auth_url: authInfo.auth_url,
                    token_url: authInfo.token_url,
                    client_id: authInfo.client_id,
                    scopes: authInfo.scopes,
                    env_variable: authInfo.env_variable
                )
            }
        )
    }
}

extension DarwinOrganizationData {
    /// Convert to capabilities-store compatible format
    public func toCapabilitiesStoreFormat() -> CapabilitiesStoreOrganization {
        return CapabilitiesStoreOrganization(
            id: self.id,
            name: self.name,
            description: self.description,
            logo: self.logo,
            pngLogo: self.pngLogo,
            svgLogo: self.svgLogo,
            types: self.types,
            children: self.children,
            tags: self.tags
        )
    }
}

// MARK: - Capabilities Store Compatible Models

/// Capabilities store compatible capability structure
public struct CapabilitiesStoreCapability: Codable {
    public let name: String
    public let description: String
    public let organization: String
    public let type: String
    public let entry_point: String?
    public let inputs: [CapabilitiesStoreInput]?
    public let output: CapabilitiesStoreOutput?
    public let auth: CapabilitiesStoreAuth?
    public let tags: [String]?
    public let categories: [String]?
    public let svgLogo: String?
    public let pngLogo: String?
    
    public init(
        name: String,
        description: String,
        organization: String,
        type: String,
        entry_point: String? = nil,
        inputs: [CapabilitiesStoreInput]? = nil,
        output: CapabilitiesStoreOutput? = nil,
        auth: CapabilitiesStoreAuth? = nil,
        tags: [String]? = nil,
        categories: [String]? = nil,
        svgLogo: String? = nil,
        pngLogo: String? = nil
    ) {
        self.name = name
        self.description = description
        self.organization = organization
        self.type = type
        self.entry_point = entry_point
        self.inputs = inputs
        self.output = output
        self.auth = auth
        self.tags = tags
        self.categories = categories
        self.svgLogo = svgLogo
        self.pngLogo = pngLogo
    }
}

/// Capabilities store compatible input structure
public struct CapabilitiesStoreInput: Codable {
    public let name: String
    public let type: String
    public let required: Bool
    public let description: String
    public let `default`: String?
    
    public init(
        name: String,
        type: String,
        required: Bool,
        description: String,
        default: String? = nil
    ) {
        self.name = name
        self.type = type
        self.required = required
        self.description = description
        self.default = `default`
    }
}

/// Capabilities store compatible output structure
public struct CapabilitiesStoreOutput: Codable {
    public let type: String
    public let description: String?
    
    public init(type: String, description: String? = nil) {
        self.type = type
        self.description = description
    }
}

/// Capabilities store compatible auth structure
public struct CapabilitiesStoreAuth: Codable {
    public let type: String
    public let auth_url: String?
    public let token_url: String?
    public let client_id: String?
    public let scopes: [String]?
    public let env_variable: String?
    
    public init(
        type: String,
        auth_url: String? = nil,
        token_url: String? = nil,
        client_id: String? = nil,
        scopes: [String]? = nil,
        env_variable: String? = nil
    ) {
        self.type = type
        self.auth_url = auth_url
        self.token_url = token_url
        self.client_id = client_id
        self.scopes = scopes
        self.env_variable = env_variable
    }
}

/// Capabilities store compatible organization structure
public struct CapabilitiesStoreOrganization: Codable {
    public let id: String
    public let name: String
    public let description: String
    public let logo: String?
    public let pngLogo: String?
    public let svgLogo: String?
    public let types: [String]
    public let children: [String]?
    public let tags: [String]?
    
    public init(
        id: String,
        name: String,
        description: String,
        logo: String? = nil,
        pngLogo: String? = nil,
        svgLogo: String? = nil,
        types: [String] = ["local"],
        children: [String]? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.logo = logo
        self.pngLogo = pngLogo
        self.svgLogo = svgLogo
        self.types = types
        self.children = children
        self.tags = tags
    }
}