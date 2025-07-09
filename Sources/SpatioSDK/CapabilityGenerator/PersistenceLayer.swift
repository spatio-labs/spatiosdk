import Foundation

/// Protocol defining the interface for persisting organizations and capabilities
public protocol PersistenceLayer {
    /// The persistence mode this layer handles
    var mode: PersistenceMode { get }
    
    /// Create a new organization
    /// - Parameters:
    ///   - organization: Organization data to create
    ///   - overwrite: Whether to overwrite if it already exists
    /// - Throws: PersistenceError if creation fails
    func createOrganization(
        _ organization: DarwinOrganizationData,
        overwrite: Bool
    ) throws
    
    /// Create a new capability
    /// - Parameters:
    ///   - capability: Capability data to create
    ///   - overwrite: Whether to overwrite if it already exists
    /// - Throws: PersistenceError if creation fails
    func createCapability(
        _ capability: DarwinCapabilityMetadata,
        overwrite: Bool
    ) throws
    
    /// List all organizations
    /// - Returns: Array of organization data
    /// - Throws: PersistenceError if listing fails
    func listOrganizations() throws -> [DarwinOrganizationData]
    
    /// List capabilities for a specific organization
    /// - Parameter organizationId: The organization ID
    /// - Returns: Array of capability data
    /// - Throws: PersistenceError if listing fails
    func listCapabilities(for organizationId: String) throws -> [DarwinCapabilityMetadata]
    
    /// Remove an organization and all its capabilities
    /// - Parameter organizationId: The organization ID to remove
    /// - Throws: PersistenceError if removal fails
    func removeOrganization(organizationId: String) throws
    
    /// Remove a specific capability
    /// - Parameters:
    ///   - capabilityName: The capability name to remove
    ///   - organizationId: The organization ID
    /// - Throws: PersistenceError if removal fails
    func removeCapability(
        capabilityName: String,
        from organizationId: String
    ) throws
    
    /// Check if an organization exists
    /// - Parameter organizationId: The organization ID to check
    /// - Returns: True if the organization exists
    func organizationExists(organizationId: String) -> Bool
    
    /// Check if a capability exists
    /// - Parameters:
    ///   - capabilityName: The capability name to check
    ///   - organizationId: The organization ID
    /// - Returns: True if the capability exists
    func capabilityExists(
        capabilityName: String,
        in organizationId: String
    ) -> Bool
}

/// Errors that can occur during persistence operations
public enum PersistenceError: Error, LocalizedError {
    case invalidMode(String)
    case organizationExists(String)
    case capabilityExists(String)
    case organizationNotFound(String)
    case capabilityNotFound(String)
    case fileSystemError(String)
    case databaseError(String)
    case validationError(String)
    case permissionDenied(String)
    case operationNotSupported(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidMode(let details):
            return "Invalid persistence mode: \(details)"
        case .organizationExists(let id):
            return "Organization '\(id)' already exists"
        case .capabilityExists(let name):
            return "Capability '\(name)' already exists"
        case .organizationNotFound(let id):
            return "Organization '\(id)' not found"
        case .capabilityNotFound(let name):
            return "Capability '\(name)' not found"
        case .fileSystemError(let details):
            return "File system error: \(details)"
        case .databaseError(let details):
            return "Database error: \(details)"
        case .validationError(let details):
            return "Validation error: \(details)"
        case .permissionDenied(let details):
            return "Permission denied: \(details)"
        case .operationNotSupported(let details):
            return "Operation not supported: \(details)"
        }
    }
}

/// Factory for creating persistence layers based on mode
public struct PersistenceLayerFactory {
    
    /// Create a persistence layer for the specified mode
    /// - Parameter mode: The persistence mode
    /// - Returns: Configured persistence layer
    /// - Throws: PersistenceError if creation fails
    public static func create(for mode: PersistenceMode) throws -> PersistenceLayer {
        // Validate the mode first
        let validationResult = mode.validate()
        if !validationResult.isValid {
            throw PersistenceError.validationError(validationResult.errors.joined(separator: ", "))
        }
        
        // Log warnings if any
        if !validationResult.warnings.isEmpty {
            for warning in validationResult.warnings {
                Logger.shared.warning(warning)
            }
        }
        
        switch mode {
        case .local:
            return try LocalPersistenceLayer()
        case .remote(let path):
            return try RemotePersistenceLayer(capabilitiesStorePath: path)
        }
    }
}