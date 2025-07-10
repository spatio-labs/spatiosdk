import Foundation

/// High-level manager for SpatioSDK operations
/// Provides a convenient interface for common capability management tasks
public class SpatioSDKManager {
    
    /// Shared instance for easy access
    public static let shared = SpatioSDKManager()
    
    /// Internal persistence layer
    private let persistenceLayer: PersistenceLayer
    
    /// Store manager for app store operations
    public let store: StoreManager
    
    /// Private initializer to enforce singleton pattern
    private init() {
        do {
            self.persistenceLayer = try PersistenceLayerFactory.create(for: .local)
            self.store = try StoreManager()
        } catch {
            fatalError("Failed to initialize SpatioSDK: \(error)")
        }
    }
    
    /// Initialize with a specific persistence mode
    /// - Parameter mode: The persistence mode to use
    /// - Throws: PersistenceError if initialization fails
    public init(mode: PersistenceMode) throws {
        self.persistenceLayer = try PersistenceLayerFactory.create(for: mode)
        self.store = try StoreManager()
    }
    
    // MARK: - Convenience Methods
    
    /// Get all installed capabilities in a UI-ready format
    /// - Returns: Array of InstalledCapability objects ready for display
    public func getInstalledCapabilities() -> [InstalledCapability] {
        do {
            let organizations = try persistenceLayer.listOrganizations()
            var allCapabilities: [InstalledCapability] = []
            
            for org in organizations {
                let capabilities = try persistenceLayer.listCapabilities(for: org.id)
                let installedCapabilities = capabilities.map { capability in
                    capability.toInstalledCapability()
                }
                allCapabilities.append(contentsOf: installedCapabilities)
            }
            
            return allCapabilities
        } catch {
            Logger.shared.error("Failed to get installed capabilities: \(error)")
            return []
        }
    }
    
    /// Get details for a specific capability
    /// - Parameter id: The capability ID
    /// - Returns: InstalledCapability object or nil if not found
    public func getCapabilityDetails(id: String) -> InstalledCapability? {
        let allCapabilities = getInstalledCapabilities()
        return allCapabilities.first { $0.id == id }
    }
    
    /// Get details for a specific capability by name
    /// - Parameters:
    ///   - name: The capability name
    ///   - organization: The organization name
    /// - Returns: InstalledCapability object or nil if not found
    public func getCapabilityDetails(name: String, organization: String) -> InstalledCapability? {
        let allCapabilities = getInstalledCapabilities()
        return allCapabilities.first { $0.name == name && $0.organization == organization }
    }
    
    /// Install a capability
    /// - Parameter capability: The capability metadata to install
    /// - Returns: Success/failure result
    public func installCapability(_ capability: DarwinCapabilityMetadata) -> Result<Void, SpatioSDKError> {
        do {
            try persistenceLayer.createCapability(capability, overwrite: false)
            Logger.shared.info("Successfully installed capability: \(capability.name)")
            return .success(())
        } catch {
            Logger.shared.error("Failed to install capability: \(error)")
            return .failure(.installationFailed(error.localizedDescription))
        }
    }
    
    /// Uninstall a capability
    /// - Parameters:
    ///   - name: The capability name
    ///   - organization: The organization name
    /// - Returns: Success/failure result
    public func uninstallCapability(name: String, organization: String) -> Result<Void, SpatioSDKError> {
        do {
            try persistenceLayer.removeCapability(capabilityName: name, organizationId: organization)
            Logger.shared.info("Successfully uninstalled capability: \(name)")
            return .success(())
        } catch {
            Logger.shared.error("Failed to uninstall capability: \(error)")
            return .failure(.uninstallationFailed(error.localizedDescription))
        }
    }
    
    /// List all organizations
    /// - Returns: Array of organization names
    public func getOrganizations() -> [String] {
        do {
            let organizations = try persistenceLayer.listOrganizations()
            return organizations.map { $0.id }
        } catch {
            Logger.shared.error("Failed to get organizations: \(error)")
            return []
        }
    }
    
    /// Get capabilities for a specific organization
    /// - Parameter organizationId: The organization ID
    /// - Returns: Array of capability metadata
    public func getCapabilities(for organizationId: String) -> [DarwinCapabilityMetadata] {
        do {
            return try persistenceLayer.listCapabilities(for: organizationId)
        } catch {
            Logger.shared.error("Failed to get capabilities for organization \(organizationId): \(error)")
            return []
        }
    }
    
    /// Create a new organization
    /// - Parameter organization: The organization data to create
    /// - Returns: Success/failure result
    public func createOrganization(_ organization: DarwinOrganizationData) -> Result<Void, SpatioSDKError> {
        do {
            try persistenceLayer.createOrganization(organization, overwrite: false)
            Logger.shared.info("Successfully created organization: \(organization.id)")
            return .success(())
        } catch {
            Logger.shared.error("Failed to create organization: \(error)")
            return .failure(.organizationCreationFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Advanced Convenience Methods
    
    /// Get installed capabilities grouped by organization
    /// - Returns: Dictionary with organization names as keys and capability arrays as values
    public func getInstalledCapabilitiesGroupedByOrganization() -> [String: [InstalledCapability]] {
        return getInstalledCapabilities().groupedByOrganization
    }
    
    /// Get installed capabilities filtered by search text
    /// - Parameter searchText: Text to filter by (searches name, organization, description)
    /// - Returns: Array of matching capabilities
    public func getInstalledCapabilities(filteredBy searchText: String) -> [InstalledCapability] {
        return getInstalledCapabilities().filtered(by: searchText)
    }
    
    /// Get installed capabilities sorted by name
    /// - Returns: Array of capabilities sorted alphabetically by name
    public func getInstalledCapabilitiesSortedByName() -> [InstalledCapability] {
        return getInstalledCapabilities().sortedByName
    }
    
    /// Get installed capabilities sorted by install date (newest first)
    /// - Returns: Array of capabilities sorted by install date
    public func getInstalledCapabilitiesSortedByInstallDate() -> [InstalledCapability] {
        return getInstalledCapabilities().sortedByInstallDate
    }
    
    /// Get enabled capabilities only
    /// - Returns: Array of enabled capabilities
    public func getEnabledCapabilities() -> [InstalledCapability] {
        return getInstalledCapabilities().enabledOnly
    }
    
    /// Check if a capability is installed
    /// - Parameters:
    ///   - name: The capability name
    ///   - organization: The organization name
    /// - Returns: True if the capability is installed
    public func isCapabilityInstalled(name: String, organization: String) -> Bool {
        return getCapabilityDetails(name: name, organization: organization) != nil
    }
    
    /// Get the total count of installed capabilities
    /// - Returns: Number of installed capabilities
    public func getInstalledCapabilityCount() -> Int {
        return getInstalledCapabilities().count
    }
    
    /// Get installed capabilities for a specific organization
    /// - Parameter organizationId: The organization ID
    /// - Returns: Array of installed capabilities for the organization
    public func getInstalledCapabilities(for organizationId: String) -> [InstalledCapability] {
        return getInstalledCapabilities().filter { $0.organization == organizationId }
    }
    
    /// Refresh capability cache (if applicable)
    /// - Returns: Success/failure result
    public func refreshCapabilityCache() -> Result<Void, SpatioSDKError> {
        do {
            try persistenceLayer.refreshAllCaches()
            Logger.shared.info("Successfully refreshed capability cache")
            return .success(())
        } catch {
            Logger.shared.error("Failed to refresh capability cache: \(error)")
            return .failure(.persistenceError(error.localizedDescription))
        }
    }
    
    /// Clear capability cache (if applicable)
    /// - Returns: Success/failure result
    public func clearCapabilityCache() -> Result<Void, SpatioSDKError> {
        do {
            try persistenceLayer.clearAllCaches()
            Logger.shared.info("Successfully cleared capability cache")
            return .success(())
        } catch {
            Logger.shared.error("Failed to clear capability cache: \(error)")
            return .failure(.persistenceError(error.localizedDescription))
        }
    }
}

// MARK: - Error Types

/// Errors that can occur in SpatioSDK operations
public enum SpatioSDKError: Error, LocalizedError {
    case installationFailed(String)
    case uninstallationFailed(String)
    case organizationCreationFailed(String)
    case capabilityNotFound(String)
    case persistenceError(String)
    
    public var errorDescription: String? {
        switch self {
        case .installationFailed(let message):
            return "Installation failed: \(message)"
        case .uninstallationFailed(let message):
            return "Uninstallation failed: \(message)"
        case .organizationCreationFailed(let message):
            return "Organization creation failed: \(message)"
        case .capabilityNotFound(let name):
            return "Capability not found: \(name)"
        case .persistenceError(let message):
            return "Persistence error: \(message)"
        }
    }
}
