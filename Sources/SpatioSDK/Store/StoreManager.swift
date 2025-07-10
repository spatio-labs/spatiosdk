import Foundation
import SQLite3
import SQLite

/// Manager for app store operations including browsing and installation
public class StoreManager {
    
    // MARK: - Properties
    
    /// Path to the cache database containing store data
    private let cacheDatabasePath: URL
    
    /// SQLite connection for cache database
    private var cacheDatabase: Connection?
    
    /// Path to the installed database
    private let installedDatabasePath: URL
    
    /// SQLite connection for installed database
    private var installedDatabase: Connection?
    
    // MARK: - Initialization
    
    public init() throws {
        // Set up paths
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let darwinDirectory = homeDirectory.appendingPathComponent(".darwin")
        let storeDirectory = darwinDirectory.appendingPathComponent("store")
        
        self.cacheDatabasePath = storeDirectory
            .appendingPathComponent("cache")
            .appendingPathComponent("apps")
            .appendingPathComponent("app-store")
            .appendingPathComponent("capabilities.sqlite")
        
        self.installedDatabasePath = storeDirectory
            .appendingPathComponent("installed.db")
        
        // Connect to databases
        try connectToDatabases()
    }
    
    // MARK: - Private Database Methods
    
    private func connectToDatabases() throws {
        // Connect to cache database if it exists
        if FileManager.default.fileExists(atPath: cacheDatabasePath.path) {
            cacheDatabase = try Connection(cacheDatabasePath.path)
            Logger.shared.info("StoreManager: Connected to cache database")
        } else {
            Logger.shared.warning("StoreManager: Cache database not found at \(cacheDatabasePath.path)")
        }
        
        // Connect to installed database if it exists
        if FileManager.default.fileExists(atPath: installedDatabasePath.path) {
            installedDatabase = try Connection(installedDatabasePath.path)
            Logger.shared.info("StoreManager: Connected to installed database")
        }
    }
    
    // MARK: - Store Browsing Methods
    
    /// List all organizations in the store
    public func listStoreOrganizations(
        page: Int = 1,
        pageSize: Int = 50
    ) throws -> StorePaginatedResponse<StoreOrganization> {
        guard let db = cacheDatabase else {
            throw StoreError.databaseNotAvailable
        }
        
        // Define table and columns
        let orgTable = Table("organizations")
        let orgId = Expression<String>("id")
        let orgName = Expression<String>("name")
        let orgDescription = Expression<String?>("description")
        let orgLogo = Expression<String?>("logo")
        let orgChildren = Expression<String?>("children")
        
        // Get total count
        let totalCount = try db.scalar(orgTable.count)
        
        // Query with pagination
        let offset = (page - 1) * pageSize
        let query = orgTable
            .order(orgName.asc)
            .limit(pageSize, offset: offset)
        
        var organizations: [StoreOrganization] = []
        
        for row in try db.prepare(query) {
            // Parse children array from JSON
            var childrenArray: [String] = []
            if let childrenJson = row[orgChildren],
               let data = childrenJson.data(using: .utf8),
               let children = try? JSONDecoder().decode([String].self, from: data) {
                childrenArray = children
            }
            
            // Determine logo URLs
            let logoUrl = row[orgLogo]
            let pngLogo = logoUrl?.contains(".png") == true ? logoUrl : nil
            let svgLogo = logoUrl?.contains(".svg") == true ? logoUrl : nil
            
            let org = StoreOrganization(
                id: row[orgId],
                name: row[orgName],
                description: row[orgDescription] ?? "",
                logoUrl: logoUrl,
                pngLogoUrl: pngLogo,
                svgLogoUrl: svgLogo,
                children: childrenArray
            )
            
            organizations.append(org)
        }
        
        return StorePaginatedResponse(
            items: organizations,
            page: page,
            pageSize: pageSize,
            totalCount: totalCount
        )
    }
    
    /// List featured organizations
    public func listFeaturedOrganizations() throws -> [FeaturedOrganization] {
        guard let db = cacheDatabase else {
            throw StoreError.databaseNotAvailable
        }
        
        // Define tables and columns
        let featuredTable = Table("featured")
        let orgTable = Table("organizations")
        let featuredOrgId = Expression<String>("organization_id")
        let displayOrder = Expression<Int>("display_order")
        let orgId = Expression<String>("id")
        let orgName = Expression<String>("name")
        let orgDescription = Expression<String?>("description")
        let orgLogo = Expression<String?>("logo")
        let orgChildren = Expression<String?>("children")
        
        // Join featured with organizations
        let query = featuredTable
            .join(orgTable, on: featuredTable[featuredOrgId] == orgTable[orgId])
            .order(displayOrder.asc)
        
        var featuredOrgs: [FeaturedOrganization] = []
        
        for row in try db.prepare(query) {
            // Parse children array
            var childrenArray: [String] = []
            if let childrenJson = row[orgTable[orgChildren]],
               let data = childrenJson.data(using: .utf8),
               let children = try? JSONDecoder().decode([String].self, from: data) {
                childrenArray = children
            }
            
            // Determine logo URLs
            let logoUrl = row[orgTable[orgLogo]]
            let pngLogo = logoUrl?.contains(".png") == true ? logoUrl : nil
            let svgLogo = logoUrl?.contains(".svg") == true ? logoUrl : nil
            
            let org = StoreOrganization(
                id: row[orgTable[orgId]],
                name: row[orgTable[orgName]],
                description: row[orgTable[orgDescription]] ?? "",
                logoUrl: logoUrl,
                pngLogoUrl: pngLogo,
                svgLogoUrl: svgLogo,
                children: childrenArray
            )
            
            let featured = FeaturedOrganization(
                id: row[orgTable[orgId]],
                organization: org,
                displayOrder: row[displayOrder]
            )
            
            featuredOrgs.append(featured)
        }
        
        Logger.shared.info("StoreManager: Found \(featuredOrgs.count) featured organizations")
        return featuredOrgs
    }
    
    /// Get organization details including capabilities
    public func getOrganizationDetails(id: String) throws -> StoreOrganizationDetail? {
        guard let db = cacheDatabase else {
            throw StoreError.databaseNotAvailable
        }
        
        // Get the organization
        let orgTable = Table("organizations")
        let orgId = Expression<String>("id")
        let orgName = Expression<String>("name")
        let orgDescription = Expression<String?>("description")
        let orgLogo = Expression<String?>("logo")
        let orgChildren = Expression<String?>("children")
        
        let orgQuery = orgTable.filter(orgId == id)
        guard let orgRow = try db.pluck(orgQuery) else {
            return nil
        }
        
        // Parse organization data
        var childrenArray: [String] = []
        if let childrenJson = orgRow[orgChildren],
           let data = childrenJson.data(using: .utf8),
           let children = try? JSONDecoder().decode([String].self, from: data) {
            childrenArray = children
        }
        
        let logoUrl = orgRow[orgLogo]
        let pngLogo = logoUrl?.contains(".png") == true ? logoUrl : nil
        let svgLogo = logoUrl?.contains(".svg") == true ? logoUrl : nil
        
        let organization = StoreOrganization(
            id: orgRow[orgId],
            name: orgRow[orgName],
            description: orgRow[orgDescription] ?? "",
            logoUrl: logoUrl,
            pngLogoUrl: pngLogo,
            svgLogoUrl: svgLogo,
            children: childrenArray
        )
        
        // Get capabilities for this organization
        let capabilities = try listCapabilities(for: id)
        
        // Get sub-organizations
        var subOrganizations: [StoreOrganization] = []
        for childId in childrenArray {
            let childQuery = orgTable.filter(orgId == childId)
            if let childRow = try db.pluck(childQuery) {
                
                let childLogoUrl = childRow[orgLogo]
                let childPngLogo = childLogoUrl?.contains(".png") == true ? childLogoUrl : nil
                let childSvgLogo = childLogoUrl?.contains(".svg") == true ? childLogoUrl : nil
                
                let subOrg = StoreOrganization(
                    id: childRow[orgId],
                    name: childRow[orgName],
                    description: childRow[orgDescription] ?? "",
                    logoUrl: childLogoUrl,
                    pngLogoUrl: childPngLogo,
                    svgLogoUrl: childSvgLogo
                )
                subOrganizations.append(subOrg)
            }
        }
        
        return StoreOrganizationDetail(
            organization: organization,
            capabilities: capabilities,
            subOrganizations: subOrganizations
        )
    }
    
    /// List capabilities for an organization
    public func listCapabilities(
        for organizationId: String,
        includeSubOrganizations: Bool = false
    ) throws -> [StoreCapability] {
        guard let db = cacheDatabase else {
            throw StoreError.databaseNotAvailable
        }
        
        // Define table and columns
        let capTable = Table("capabilities")
        let capId = Expression<String>("id")
        let capName = Expression<String>("name")
        let capDescription = Expression<String?>("description")
        let capOrgId = Expression<String>("organization_id")
        let capVersion = Expression<String?>("version")
        let capType = Expression<String?>("type")
        let capEntryPoint = Expression<String?>("entry_point")
        
        // Build query
        var query = capTable.filter(capOrgId == organizationId)
        
        // If including sub-organizations, use LIKE query
        if includeSubOrganizations {
            query = capTable.filter(
                capOrgId == organizationId ||
                capOrgId.like("\(organizationId)/%")
            )
        }
        
        var capabilities: [StoreCapability] = []
        
        for row in try db.prepare(query) {
            // Check if installed
            let isInstalled = try checkIfInstalled(capabilityId: row[capId])
            
            let capability = StoreCapability(
                id: row[capId],
                name: row[capName],
                description: row[capDescription] ?? "",
                organizationId: row[capOrgId],
                version: row[capVersion] ?? "1.0.0",
                entryPoint: row[capEntryPoint] ?? "main",
                type: row[capType] ?? "function",
                isInstalled: isInstalled
            )
            
            capabilities.append(capability)
        }
        
        return capabilities
    }
    
    /// Search organizations by query
    public func searchOrganizations(
        query: String,
        filters: StoreSearchFilters = StoreSearchFilters()
    ) throws -> [StoreOrganization] {
        guard let db = cacheDatabase else {
            throw StoreError.databaseNotAvailable
        }
        
        // For now, simple name/description search
        let orgTable = Table("organizations")
        let orgId = Expression<String>("id")
        let orgName = Expression<String>("name")
        let orgDescription = Expression<String?>("description")
        let orgLogo = Expression<String?>("logo")
        
        let searchQuery = orgTable.filter(
            orgName.lowercaseString.like("%\(query.lowercased())%") ||
            orgDescription.lowercaseString.like("%\(query.lowercased())%")
        )
        
        var organizations: [StoreOrganization] = []
        
        for row in try db.prepare(searchQuery) {
            let logoUrl = row[orgLogo]
            let pngLogo = logoUrl?.contains(".png") == true ? logoUrl : nil
            let svgLogo = logoUrl?.contains(".svg") == true ? logoUrl : nil
            
            let org = StoreOrganization(
                id: row[orgId],
                name: row[orgName],
                description: row[orgDescription] ?? "",
                logoUrl: logoUrl,
                pngLogoUrl: pngLogo,
                svgLogoUrl: svgLogo
            )
            
            organizations.append(org)
        }
        
        return organizations
    }
    
    // MARK: - Installation Status Methods
    
    /// Check if a capability is installed
    private func checkIfInstalled(capabilityId: String) throws -> Bool {
        guard let db = installedDatabase else {
            return false
        }
        
        let capTable = Table("capabilities")
        let capId = Expression<String>("id")
        let isInstalled = Expression<Bool>("is_installed")
        
        let query = capTable
            .select(isInstalled)
            .filter(capId == capabilityId)
        
        if let row = try db.pluck(query) {
            return row[isInstalled]
        }
        
        return false
    }
    
    /// Get installation status for an item
    public func getInstallationStatus(for itemId: String) -> StoreInstallationStatus {
        // This would integrate with the actual installation system
        // For now, return a basic status
        do {
            if try checkIfInstalled(capabilityId: itemId) {
                return .installed
            } else {
                return .notInstalled
            }
        } catch {
            return .notInstalled
        }
    }
    
    // MARK: - Installation Methods (Placeholders)
    
    /// Install an organization and all its capabilities
    public func installOrganization(_ organizationId: String) async throws {
        // This would coordinate with RemoteCapabilityService
        // Placeholder for now
        throw StoreError.notImplemented("Organization installation not yet implemented")
    }
    
    /// Install a specific capability
    public func installCapability(
        organizationId: String,
        capabilityId: String
    ) async throws {
        // This would coordinate with RemoteCapabilityService
        // Placeholder for now
        throw StoreError.notImplemented("Capability installation not yet implemented")
    }
    
    /// Cancel an ongoing installation
    public func cancelInstallation(for itemId: String) {
        // Placeholder
        Logger.shared.info("StoreManager: Cancel installation requested for \(itemId)")
    }
}

// MARK: - Store Errors

public enum StoreError: LocalizedError {
    case databaseNotAvailable
    case organizationNotFound(String)
    case capabilityNotFound(String)
    case installationFailed(String)
    case notImplemented(String)
    
    public var errorDescription: String? {
        switch self {
        case .databaseNotAvailable:
            return "Store database is not available"
        case .organizationNotFound(let id):
            return "Organization not found: \(id)"
        case .capabilityNotFound(let id):
            return "Capability not found: \(id)"
        case .installationFailed(let reason):
            return "Installation failed: \(reason)"
        case .notImplemented(let feature):
            return "\(feature)"
        }
    }
}