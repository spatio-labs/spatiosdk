import Foundation

/// Main API for programmatically creating organizations and capabilities
/// Compatible with both Darwin AI local storage and capabilities-store formats
public class CapabilityGenerator {
    
    /// The persistence layer handling actual storage operations
    private let persistenceLayer: PersistenceLayer
    
    /// The persistence mode being used
    public let mode: PersistenceMode
    
    /// Initialize with a specific persistence mode
    /// - Parameter mode: The persistence mode to use
    /// - Throws: PersistenceError if the mode is invalid
    public init(mode: PersistenceMode) throws {
        self.mode = mode
        self.persistenceLayer = try PersistenceLayerFactory.create(for: mode)
    }
    
    // MARK: - Organization Management
    
    /// Create a new organization programmatically
    /// - Parameters:
    ///   - organization: Darwin AI organization data
    ///   - overwrite: Whether to overwrite existing organization
    /// - Returns: Created organization metadata
    /// - Throws: PersistenceError if creation fails
    public func createOrganization(
        _ organization: DarwinOrganizationData,
        overwrite: Bool = false
    ) throws -> DarwinOrganizationData {
        try persistenceLayer.createOrganization(organization, overwrite: overwrite)
        Logger.shared.info("Created organization: \(organization.id) using \(mode)")
        return organization
    }
    
    /// List all existing organizations
    /// - Returns: Array of organization metadata
    /// - Throws: PersistenceError if listing fails
    public func listOrganizations() throws -> [DarwinOrganizationData] {
        return try persistenceLayer.listOrganizations()
    }
    
    /// Remove an organization and all its capabilities
    /// - Parameter organizationId: The organization ID to remove
    /// - Throws: PersistenceError if removal fails
    public func removeOrganization(organizationId: String) throws {
        try persistenceLayer.removeOrganization(organizationId: organizationId)
        Logger.shared.info("Removed organization: \(organizationId) using \(mode)")
    }
    
    // MARK: - Capability Management
    
    /// Create a new capability programmatically
    /// - Parameters:
    ///   - capability: Darwin AI capability metadata
    ///   - overwrite: Whether to overwrite existing capability
    /// - Returns: Created capability metadata
    /// - Throws: PersistenceError if creation fails
    public func createCapability(
        _ capability: DarwinCapabilityMetadata,
        overwrite: Bool = false
    ) throws -> DarwinCapabilityMetadata {
        try persistenceLayer.createCapability(capability, overwrite: overwrite)
        Logger.shared.info("Created capability: \(capability.name) in organization: \(capability.organization) using \(mode)")
        return capability
    }
    
    /// List all capabilities for a specific organization
    /// - Parameter organizationId: The organization ID
    /// - Returns: Array of capability metadata
    /// - Throws: PersistenceError if listing fails
    public func listCapabilities(for organizationId: String) throws -> [DarwinCapabilityMetadata] {
        return try persistenceLayer.listCapabilities(for: organizationId)
    }
    
    /// Remove a specific capability from an organization
    /// - Parameters:
    ///   - capabilityName: The capability name to remove
    ///   - organizationId: The organization ID
    /// - Throws: PersistenceError if removal fails
    public func removeCapability(
        capabilityName: String,
        from organizationId: String
    ) throws {
        try persistenceLayer.removeCapability(capabilityName: capabilityName, from: organizationId)
        Logger.shared.info("Removed capability: \(capabilityName) from organization: \(organizationId) using \(mode)")
    }
    
    // MARK: - Validation
    
    /// Validate an organization configuration
    /// - Parameter organization: Organization to validate
    /// - Returns: Validation result
    public func validateOrganization(_ organization: DarwinOrganizationData) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Check required fields
        if organization.id.isEmpty {
            errors.append("Organization ID is required")
        }
        
        if organization.name.isEmpty {
            errors.append("Organization name is required")
        }
        
        if organization.description.isEmpty {
            errors.append("Organization description is required")
        }
        
        // Check ID format
        if !organization.id.matches(pattern: "^[a-zA-Z0-9_-]+$") {
            errors.append("Organization ID can only contain alphanumeric characters, hyphens, and underscores")
        }
        
        // Check for logo consistency
        if organization.logo != nil && (organization.pngLogo != nil || organization.svgLogo != nil) {
            warnings.append("Both legacy 'logo' and new 'pngLogo'/'svgLogo' fields are present. Consider using only 'pngLogo' and 'svgLogo'")
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    /// Validate a capability configuration
    /// - Parameter capability: Capability to validate
    /// - Returns: Validation result
    public func validateCapability(_ capability: DarwinCapabilityMetadata) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Check required fields
        if capability.name.isEmpty {
            errors.append("Capability name is required")
        }
        
        if capability.description.isEmpty {
            errors.append("Capability description is required")
        }
        
        if capability.organization.isEmpty {
            errors.append("Capability organization is required")
        }
        
        if capability.entry_point.isEmpty {
            errors.append("Capability entry_point is required")
        }
        
        // Check parameter consistency
        for (index, param) in capability.inputs.enumerated() {
            if param.name.isEmpty {
                errors.append("Parameter \(index) name is required")
            }
            
            if param.type.isEmpty {
                errors.append("Parameter \(index) type is required")
            }
            
            if param.description.isEmpty {
                errors.append("Parameter \(index) description is required")
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    // MARK: - Helper Methods
    
    /// Convert capabilities-store format to Darwin AI format
    private func convertToDarwinFormat(_ capJson: CapabilitiesStoreCapability) throws -> DarwinCapabilityMetadata {
        let inputs = capJson.inputs?.map { input in
            DarwinFunctionParameter(
                name: input.name,
                type: input.type,
                required: input.required,
                defaultValue: input.default,
                description: input.description,
                context: nil
            )
        } ?? []
        
        let output = DarwinCapabilityOutput(
            type: capJson.output?.type ?? "string",
            description: capJson.output?.description,
            properties: nil
        )
        
        let authType = DarwinAuthenticationType(rawValue: capJson.auth?.type ?? "None") ?? .none
        
        let auth = capJson.auth.map { authInfo in
            DarwinCapabilityAuthInfo(
                type: authInfo.type,
                auth_url: authInfo.auth_url,
                token_url: authInfo.token_url,
                client_id: authInfo.client_id,
                scopes: authInfo.scopes,
                env_variable: authInfo.env_variable
            )
        }
        
        return DarwinCapabilityMetadata(
            type: capJson.type,
            name: capJson.name,
            description: capJson.description,
            entry_point: capJson.entry_point ?? "",
            organization: capJson.organization,
            group: capJson.organization, // Default group to organization
            inputs: inputs,
            output: output,
            auth_type: authType,
            auth: auth
        )
    }
}

// MARK: - Error Types

/// Errors that can occur during capability generation
public enum CapabilityGeneratorError: Error, LocalizedError {
    case invalidPath(String)
    case organizationExists(String)
    case capabilityExists(String)
    case validationFailed([String])
    case fileSystemError(String)
    case buildError(String)
    case deploymentError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .organizationExists(let id):
            return "Organization '\(id)' already exists"
        case .capabilityExists(let name):
            return "Capability '\(name)' already exists"
        case .validationFailed(let errors):
            return "Validation failed: \(errors.joined(separator: ", "))"
        case .fileSystemError(let error):
            return "File system error: \(error)"
        case .buildError(let error):
            return "Build error: \(error)"
        case .deploymentError(let error):
            return "Deployment error: \(error)"
        }
    }
}

// MARK: - Result Types

/// Result of a validation operation
public struct ValidationResult {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    
    public init(isValid: Bool, errors: [String] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

// MARK: - String Extensions

extension String {
    func matches(pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}