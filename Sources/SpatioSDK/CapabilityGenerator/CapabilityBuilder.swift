import Foundation

/// Builder class for creating capabilities with a fluent interface
public class CapabilityBuilder {
    private var name: String = ""
    private var description: String = ""
    private var type: String = "local"
    private var entryPoint: String = ""
    private var organization: String = ""
    private var group: String = ""
    private var inputs: [DarwinFunctionParameter] = []
    private var output: DarwinCapabilityOutput = DarwinCapabilityOutput(type: "string")
    private var baseUrl: String?
    private var authType: DarwinAuthenticationType = .none
    private var headers: [DarwinCapabilityHeader]?
    private var auth: DarwinCapabilityAuthInfo?
    
    public init() {}
    
    // MARK: - Basic Configuration
    
    @discardableResult
    public func name(_ name: String) -> CapabilityBuilder {
        self.name = name
        return self
    }
    
    @discardableResult
    public func description(_ description: String) -> CapabilityBuilder {
        self.description = description
        return self
    }
    
    @discardableResult
    public func type(_ type: String) -> CapabilityBuilder {
        self.type = type
        return self
    }
    
    @discardableResult
    public func entryPoint(_ entryPoint: String) -> CapabilityBuilder {
        self.entryPoint = entryPoint
        return self
    }
    
    @discardableResult
    public func organization(_ organization: String) -> CapabilityBuilder {
        self.organization = organization
        return self
    }
    
    @discardableResult
    public func group(_ group: String) -> CapabilityBuilder {
        self.group = group
        return self
    }
    
    // MARK: - Input Parameters
    
    @discardableResult
    public func addInput(
        name: String,
        type: String,
        required: Bool = false,
        defaultValue: String? = nil,
        description: String,
        context: [String]? = nil
    ) -> CapabilityBuilder {
        let parameter = DarwinFunctionParameter(
            name: name,
            type: type,
            required: required,
            defaultValue: defaultValue,
            description: description,
            context: context
        )
        inputs.append(parameter)
        return self
    }
    
    @discardableResult
    public func addRequiredInput(
        name: String,
        type: String,
        description: String,
        context: [String]? = nil
    ) -> CapabilityBuilder {
        return addInput(
            name: name,
            type: type,
            required: true,
            description: description,
            context: context
        )
    }
    
    @discardableResult
    public func addOptionalInput(
        name: String,
        type: String,
        defaultValue: String? = nil,
        description: String,
        context: [String]? = nil
    ) -> CapabilityBuilder {
        return addInput(
            name: name,
            type: type,
            required: false,
            defaultValue: defaultValue,
            description: description,
            context: context
        )
    }
    
    // MARK: - Output Configuration
    
    @discardableResult
    public func output(
        type: String,
        description: String? = nil,
        properties: [String: DarwinOutputProperty]? = nil
    ) -> CapabilityBuilder {
        self.output = DarwinCapabilityOutput(
            type: type,
            description: description,
            properties: properties
        )
        return self
    }
    
    @discardableResult
    public func stringOutput(description: String? = nil) -> CapabilityBuilder {
        return output(type: "string", description: description)
    }
    
    @discardableResult
    public func objectOutput(description: String? = nil) -> CapabilityBuilder {
        return output(type: "object", description: description)
    }
    
    @discardableResult
    public func arrayOutput(description: String? = nil) -> CapabilityBuilder {
        return output(type: "array", description: description)
    }
    
    // MARK: - Authentication Configuration
    
    @discardableResult
    public func noAuth() -> CapabilityBuilder {
        self.authType = .none
        return self
    }
    
    @discardableResult
    public func apiKeyAuth(envVariable: String) -> CapabilityBuilder {
        self.authType = .apiKey
        self.auth = DarwinCapabilityAuthInfo(
            type: "apiKey",
            env_variable: envVariable
        )
        return self
    }
    
    @discardableResult
    public func oauth2Auth(
        authUrl: String,
        tokenUrl: String,
        clientId: String? = nil,
        scopes: [String]? = nil
    ) -> CapabilityBuilder {
        self.authType = .oauth2
        self.auth = DarwinCapabilityAuthInfo(
            type: "oauth2",
            auth_url: authUrl,
            token_url: tokenUrl,
            client_id: clientId,
            scopes: scopes
        )
        return self
    }
    
    @discardableResult
    public func basicAuth(envVariable: String) -> CapabilityBuilder {
        self.authType = .basic
        self.auth = DarwinCapabilityAuthInfo(
            type: "basic",
            env_variable: envVariable
        )
        return self
    }
    
    // MARK: - HTTP Configuration
    
    @discardableResult
    public func baseUrl(_ baseUrl: String) -> CapabilityBuilder {
        self.baseUrl = baseUrl
        return self
    }
    
    @discardableResult
    public func addHeader(key: String, value: String) -> CapabilityBuilder {
        if headers == nil {
            headers = []
        }
        headers?.append(DarwinCapabilityHeader(key: key, value: value))
        return self
    }
    
    // MARK: - Build Method
    
    public func build() throws -> DarwinCapabilityMetadata {
        // Validate required fields
        guard !name.isEmpty else {
            throw CapabilityBuilderError.missingRequiredField("name")
        }
        
        guard !description.isEmpty else {
            throw CapabilityBuilderError.missingRequiredField("description")
        }
        
        guard !organization.isEmpty else {
            throw CapabilityBuilderError.missingRequiredField("organization")
        }
        
        guard !entryPoint.isEmpty else {
            throw CapabilityBuilderError.missingRequiredField("entryPoint")
        }
        
        // Default group to organization if not specified
        let finalGroup = group.isEmpty ? organization : group
        
        return DarwinCapabilityMetadata(
            type: type,
            name: name,
            description: description,
            entry_point: entryPoint,
            organization: organization,
            group: finalGroup,
            inputs: inputs,
            output: output,
            base_url: baseUrl,
            auth_type: authType,
            headers: headers,
            auth: auth
        )
    }
}

/// Builder class for creating organizations with a fluent interface
public class OrganizationBuilder {
    private var id: String = ""
    private var name: String = ""
    private var description: String = ""
    private var logo: String?
    private var pngLogo: String?
    private var svgLogo: String?
    private var types: [String] = ["local"]
    private var children: [String]?
    private var tags: [String]?
    
    public init() {}
    
    // MARK: - Basic Configuration
    
    @discardableResult
    public func id(_ id: String) -> OrganizationBuilder {
        self.id = id
        return self
    }
    
    @discardableResult
    public func name(_ name: String) -> OrganizationBuilder {
        self.name = name
        return self
    }
    
    @discardableResult
    public func description(_ description: String) -> OrganizationBuilder {
        self.description = description
        return self
    }
    
    // MARK: - Logo Configuration
    
    @discardableResult
    public func logo(_ logo: String) -> OrganizationBuilder {
        self.logo = logo
        return self
    }
    
    @discardableResult
    public func pngLogo(_ pngLogo: String) -> OrganizationBuilder {
        self.pngLogo = pngLogo
        return self
    }
    
    @discardableResult
    public func svgLogo(_ svgLogo: String) -> OrganizationBuilder {
        self.svgLogo = svgLogo
        return self
    }
    
    // MARK: - Type Configuration
    
    @discardableResult
    public func types(_ types: [String]) -> OrganizationBuilder {
        self.types = types
        return self
    }
    
    @discardableResult
    public func localType() -> OrganizationBuilder {
        return types(["local"])
    }
    
    @discardableResult
    public func remoteType() -> OrganizationBuilder {
        return types(["remote"])
    }
    
    @discardableResult
    public func hybridType() -> OrganizationBuilder {
        return types(["local", "remote"])
    }
    
    @discardableResult
    public func builtinType() -> OrganizationBuilder {
        return types(["local", "builtin"])
    }
    
    // MARK: - Hierarchy Configuration
    
    @discardableResult
    public func children(_ children: [String]) -> OrganizationBuilder {
        self.children = children
        return self
    }
    
    @discardableResult
    public func addChild(_ child: String) -> OrganizationBuilder {
        if children == nil {
            children = []
        }
        children?.append(child)
        return self
    }
    
    // MARK: - Tags Configuration
    
    @discardableResult
    public func tags(_ tags: [String]) -> OrganizationBuilder {
        self.tags = tags
        return self
    }
    
    @discardableResult
    public func addTag(_ tag: String) -> OrganizationBuilder {
        if tags == nil {
            tags = []
        }
        tags?.append(tag)
        return self
    }
    
    // MARK: - Build Method
    
    public func build() throws -> DarwinOrganizationData {
        // Validate required fields
        guard !id.isEmpty else {
            throw CapabilityBuilderError.missingRequiredField("id")
        }
        
        guard !name.isEmpty else {
            throw CapabilityBuilderError.missingRequiredField("name")
        }
        
        guard !description.isEmpty else {
            throw CapabilityBuilderError.missingRequiredField("description")
        }
        
        return DarwinOrganizationData(
            id: id,
            name: name,
            description: description,
            logo: logo,
            pngLogo: pngLogo,
            svgLogo: svgLogo,
            types: types,
            children: children,
            tags: tags
        )
    }
}

// MARK: - Error Types

public enum CapabilityBuilderError: Error, LocalizedError {
    case missingRequiredField(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        }
    }
}

// MARK: - Convenience Extensions

extension CapabilityGenerator {
    
    /// Create a capability using the builder pattern
    /// - Parameter builderBlock: Closure that configures the capability builder
    /// - Returns: Created capability metadata
    /// - Throws: CapabilityGeneratorError if creation fails
    public func createCapability(
        overwrite: Bool = false,
        _ builderBlock: (CapabilityBuilder) -> Void
    ) throws -> DarwinCapabilityMetadata {
        let builder = CapabilityBuilder()
        builderBlock(builder)
        let capability = try builder.build()
        return try createCapability(capability, overwrite: overwrite)
    }
    
    /// Create an organization using the builder pattern
    /// - Parameter builderBlock: Closure that configures the organization builder
    /// - Returns: Created organization metadata
    /// - Throws: CapabilityGeneratorError if creation fails
    public func createOrganization(
        overwrite: Bool = false,
        _ builderBlock: (OrganizationBuilder) -> Void
    ) throws -> DarwinOrganizationData {
        let builder = OrganizationBuilder()
        builderBlock(builder)
        let organization = try builder.build()
        return try createOrganization(organization, overwrite: overwrite)
    }
}