import Foundation
import SQLite

/// Local persistence layer implementation for Darwin AI's installed.db
/// Extracted and adapted from Darwin AI's CapabilityStorageManager.swift
public class LocalPersistenceLayer: PersistenceLayer {
    
    // MARK: - PersistenceLayer Protocol
    
    public let mode: PersistenceMode = .local
    
    // MARK: - Properties
    
    /// SQLite database connection
    private var database: Connection?
    
    /// Path to the capabilities directory
    private let capabilitiesDirectory: URL
    
    /// Path to the repository subdirectory
    private let repositoryDirectory: URL
    
    /// Path to the cache subdirectory
    private let cacheDirectory: URL
    
    /// Path to the config subdirectory
    private let configDirectory: URL
    
    /// Path to the SQLite database
    private let databasePath: URL
    
    /// Cache manager for fast capability loading
    private var cacheManager: CapabilityCacheManager!
    
    /// JSON encoder for metadata
    private let jsonEncoder = JSONEncoder()
    
    /// JSON decoder for metadata
    private let jsonDecoder = JSONDecoder()
    
    // MARK: - Table Definitions
    
    private let organizations = Table("organizations")
    private let capabilities = Table("capabilities")
    private let capabilityParameters = Table("capability_parameters")
    private let installations = Table("installations")
    private let capabilityUsage = Table("capability_usage")
    
    // MARK: - Column Definitions
    
    // Organizations columns
    private let orgId = Expression<String>("id")
    private let orgName = Expression<String>("name")
    private let orgDescription = Expression<String?>("description")
    private let orgLogoUrl = Expression<String?>("logo_url")
    private let orgIsInstalled = Expression<Bool>("is_installed")
    private let orgIsLocalOnly = Expression<Bool>("is_local_only")
    private let orgCreatedAt = Expression<Int64>("created_at")
    private let orgUpdatedAt = Expression<Int64>("updated_at")
    private let orgMetadataJson = Expression<String?>("metadata_json")
    
    // Capabilities columns
    private let capId = Expression<String>("id")
    private let capName = Expression<String>("name")
    private let capOrgId = Expression<String>("organization_id")
    private let capDescription = Expression<String?>("description")
    private let capType = Expression<String>("type")
    private let capEntryPoint = Expression<String?>("entry_point")
    private let capFilePath = Expression<String>("path")
    // Columns that don't exist in the actual database are commented out
    // private let capLogoUrl = Expression<String?>("logo_url")
    // private let capIsInstalled = Expression<Bool>("is_installed")
    // private let capVersion = Expression<String?>("version")
    // private let capCreatedAt = Expression<Int64>("created_at")
    // private let capLastExecutedAt = Expression<Int64?>("last_executed_at")
    // private let capExecutionCount = Expression<Int64>("execution_count")
    // private let capTags = Expression<String?>("tags")
    // private let capMetadataJson = Expression<String?>("metadata_json")
    private let capInstalledAt = Expression<String?>("installed_at")
    private let capInputs = Expression<String?>("inputs")
    private let capOutputs = Expression<String?>("outputs")
    private let capAuthType = Expression<String?>("auth_type")
    
    // Parameters columns
    private let paramId = Expression<Int64>("id")
    private let paramCapId = Expression<String>("capability_id")
    private let paramName = Expression<String>("name")
    private let paramType = Expression<String>("type")
    private let paramRequired = Expression<Bool>("required")
    private let paramDescription = Expression<String?>("description")
    private let paramDefaultValue = Expression<String?>("default_value")
    
    // Installations columns
    private let instCapId = Expression<String>("capability_id")
    private let instInstalledAt = Expression<Int64>("installed_at")
    private let instSource = Expression<String?>("installation_source")
    private let instMetadata = Expression<String?>("installation_metadata")
    
    // Usage columns
    private let usageId = Expression<Int64>("id")
    private let usageCapId = Expression<String>("capability_id")
    private let usageExecutedAt = Expression<Int64>("executed_at")
    private let usageExecutionTime = Expression<Int64?>("execution_time_ms")
    private let usageSuccess = Expression<Bool?>("success")
    private let usageErrorMessage = Expression<String?>("error_message")
    private let usageParametersJson = Expression<String?>("parameters_json")
    
    // MARK: - Initialization
    
    public init() throws {
        // Set up directory structure
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let darwinDirectory = homeDirectory.appendingPathComponent(".darwin")
        capabilitiesDirectory = darwinDirectory.appendingPathComponent("store")
        repositoryDirectory = capabilitiesDirectory.appendingPathComponent("repository")
        cacheDirectory = capabilitiesDirectory.appendingPathComponent("cache")
        configDirectory = darwinDirectory.appendingPathComponent("config")
        databasePath = capabilitiesDirectory.appendingPathComponent("installed.db")
        
        // Create directories if needed
        try createDirectoryStructure()
        
        // Initialize database
        try setupDatabase()
        
        // Initialize cache manager
        cacheManager = CapabilityCacheManager(cacheDirectory: cacheDirectory, persistenceLayer: self)
        
        Logger.shared.info("LocalPersistenceLayer initialized at: \(databasePath.path)")
    }
    
    // MARK: - PersistenceLayer Implementation
    
    public func createOrganization(
        _ organization: DarwinOrganizationData,
        overwrite: Bool
    ) throws {
        if !overwrite && organizationExists(organizationId: organization.id) {
            throw PersistenceError.organizationExists(organization.id)
        }
        
        let localOrg = organization.toLocalOrganizationData(isInstalled: true)
        
        guard let db = database else {
            throw PersistenceError.databaseError("Database not initialized")
        }
        
        do {
            try db.run(organizations.insert(or: overwrite ? .replace : .abort,
                orgId <- localOrg.id,
                orgName <- localOrg.name,
                orgDescription <- localOrg.description,
                orgLogoUrl <- localOrg.logoUrl,
                orgIsInstalled <- localOrg.isInstalled,
                orgIsLocalOnly <- localOrg.isLocalOnly,
                orgCreatedAt <- localOrg.createdAt,
                orgUpdatedAt <- localOrg.updatedAt,
                orgMetadataJson <- localOrg.metadataJson
            ))
            
            // Create organization directory in repository
            let orgDir = repositoryDirectory.appendingPathComponent(organization.id)
            try FileManager.default.createDirectory(at: orgDir, withIntermediateDirectories: true)
            
            // Create org.json file
            let orgJsonPath = orgDir.appendingPathComponent("org.json")
            let orgJsonData = try jsonEncoder.encode(organization.toCapabilitiesStoreFormat())
            try orgJsonData.write(to: orgJsonPath)
            
            // Refresh caches after successful creation
            try cacheManager.refreshOrganizationsCache()
            try cacheManager.refreshMetadataCache()
            
        } catch {
            throw PersistenceError.databaseError("Failed to create organization: \(error)")
        }
    }
    
    public func createCapability(
        _ capability: DarwinCapabilityMetadata,
        overwrite: Bool
    ) throws {
        if !overwrite && capabilityExists(capabilityName: capability.name, in: capability.organization) {
            throw PersistenceError.capabilityExists(capability.name)
        }
        
        // Ensure organization exists
        if !organizationExists(organizationId: capability.organization) {
            throw PersistenceError.organizationNotFound(capability.organization)
        }
        
        // Create capability directory and files
        let capDir = repositoryDirectory
            .appendingPathComponent(capability.organization)
            .appendingPathComponent(capability.name)
        
        try FileManager.default.createDirectory(at: capDir, withIntermediateDirectories: true)
        
        // Create capability.json file
        let capJsonPath = capDir.appendingPathComponent("capability.json")
        let capJsonData = try jsonEncoder.encode(capability.toCapabilitiesStoreFormat())
        try capJsonData.write(to: capJsonPath)
        
        // Convert to local capability data
        let relativePath = "\(capability.organization)/\(capability.name)"
        let localCap = capability.toLocalCapabilityData(
            filePath: relativePath,
            isInstalled: true
        )
        
        guard let db = database else {
            throw PersistenceError.databaseError("Database not initialized")
        }
        
        do {
            try db.run(capabilities.insert(or: overwrite ? .replace : .abort,
                capId <- localCap.id,
                capName <- localCap.name,
                capOrgId <- localCap.organizationId,
                capDescription <- localCap.description,
                capType <- localCap.type,
                capEntryPoint <- localCap.entryPoint,
                capFilePath <- localCap.filePath,
                capInputs <- nil,  // TODO: Serialize inputs
                capOutputs <- nil,  // TODO: Serialize outputs
                capAuthType <- capability.auth_type.rawValue
            ))
            
            // Record installation
            try db.run(installations.insert(or: .replace,
                instCapId <- localCap.id,
                instInstalledAt <- Int64(Date().timeIntervalSince1970),
                instSource <- "spatiosdk"
            ))
            
            // Refresh caches after successful creation
            try cacheManager.refreshInstalledCache()
            try cacheManager.refreshSearchIndex()
            try cacheManager.refreshMetadataCache()
            
        } catch {
            throw PersistenceError.databaseError("Failed to create capability: \(error)")
        }
    }
    
    public func listOrganizations() throws -> [DarwinOrganizationData] {
        guard let db = database else {
            throw PersistenceError.databaseError("Database not initialized")
        }
        
        do {
            let query = organizations.filter(orgIsInstalled == true)
            let rows = try db.prepare(query)
            
            return try rows.map { row in
                let localOrg = LocalOrganizationData(
                    id: row[orgId],
                    name: row[orgName],
                    description: row[orgDescription],
                    logoUrl: row[orgLogoUrl],
                    isInstalled: row[orgIsInstalled],
                    isLocalOnly: row[orgIsLocalOnly],
                    createdAt: row[orgCreatedAt],
                    metadataJson: row[orgMetadataJson]
                )
                return localOrg.toDarwinOrganizationData()
            }
        } catch {
            throw PersistenceError.databaseError("Failed to list organizations: \(error)")
        }
    }
    
    public func listCapabilities(for organizationId: String) throws -> [DarwinCapabilityMetadata] {
        guard let db = database else {
            throw PersistenceError.databaseError("Database not initialized")
        }
        
        do {
            // Check if capability is installed by checking installations table
            let query = capabilities
                .join(installations, on: capabilities[capId] == installations[instCapId])
                .filter(capOrgId == organizationId)
            let rows = try db.prepare(query)
            
            return try rows.map { row in
                try parseCapabilityMetadata(from: row)
            }
        } catch {
            throw PersistenceError.databaseError("Failed to list capabilities: \(error)")
        }
    }
    
    public func listInstalledCapabilities() throws -> [DarwinCapabilityMetadata] {
        guard let db = database else {
            throw PersistenceError.databaseError("Database not initialized")
        }
        
        do {
            // Query capabilities that have an entry in the installations table
            let query = capabilities
                .join(installations, on: capabilities[capId] == installations[instCapId])
            
            let rows = try db.prepare(query)
            
            return try rows.map { row in
                try parseCapabilityMetadata(from: row)
            }
        } catch {
            throw PersistenceError.databaseError("Failed to list installed capabilities: \(error)")
        }
    }
    
    public func removeOrganization(organizationId: String) throws {
        guard let db = database else {
            throw PersistenceError.databaseError("Database not initialized")
        }
        
        do {
            // Remove from database (cascade will handle related records)
            let orgQuery = organizations.filter(orgId == organizationId)
            try db.run(orgQuery.delete())
            
            // Remove from file system
            let orgDir = repositoryDirectory.appendingPathComponent(organizationId)
            if FileManager.default.fileExists(atPath: orgDir.path) {
                try FileManager.default.removeItem(at: orgDir)
            }
            
            // Refresh caches after successful removal
            try cacheManager.refreshOrganizationsCache()
            try cacheManager.refreshMetadataCache()
            try cacheManager.refreshInstalledCache()
            try cacheManager.refreshSearchIndex()
            
        } catch {
            throw PersistenceError.databaseError("Failed to remove organization: \(error)")
        }
    }
    
    public func removeCapability(
        capabilityName: String,
        from organizationId: String
    ) throws {
        guard let db = database else {
            throw PersistenceError.databaseError("Database not initialized")
        }
        
        do {
            // Find capability ID
            let query = capabilities.filter(capOrgId == organizationId && capName == capabilityName)
            guard let row = try db.pluck(query) else {
                throw PersistenceError.capabilityNotFound(capabilityName)
            }
            
            let capabilityId = row[capId]
            
            // Remove from database
            try db.run(capabilities.filter(capId == capabilityId).delete())
            
            // Remove from file system
            let capDir = repositoryDirectory
                .appendingPathComponent(organizationId)
                .appendingPathComponent(capabilityName)
            
            if FileManager.default.fileExists(atPath: capDir.path) {
                try FileManager.default.removeItem(at: capDir)
            }
            
            // Refresh caches after successful removal
            try cacheManager.refreshInstalledCache()
            try cacheManager.refreshSearchIndex()
            try cacheManager.refreshMetadataCache()
            
        } catch {
            throw PersistenceError.databaseError("Failed to remove capability: \(error)")
        }
    }
    
    public func organizationExists(organizationId: String) -> Bool {
        guard let db = database else { return false }
        
        do {
            let query = organizations.filter(orgId == organizationId).limit(1)
            return try db.pluck(query) != nil
        } catch {
            return false
        }
    }
    
    public func capabilityExists(
        capabilityName: String,
        in organizationId: String
    ) -> Bool {
        guard let db = database else { return false }
        
        do {
            let query = capabilities.filter(capOrgId == organizationId && capName == capabilityName).limit(1)
            return try db.pluck(query) != nil
        } catch {
            return false
        }
    }
    
    // MARK: - Cache Management
    
    /// Refresh all caches
    public func refreshCaches() throws {
        try cacheManager.refreshAllCaches()
    }
    
    /// Clear all caches
    public func clearCaches() throws {
        try cacheManager.clearAllCaches()
    }
    
    /// Load installed capabilities from cache
    public func loadInstalledCapabilitiesFromCache() throws -> InstalledCapabilitiesCache? {
        return try cacheManager.loadInstalledCapabilities()
    }
    
    /// Load search index from cache
    public func loadSearchIndexFromCache() throws -> CapabilitySearchIndex? {
        return try cacheManager.loadSearchIndex()
    }
    
    /// Load organizations from cache
    public func loadOrganizationsFromCache() throws -> OrganizationsCache? {
        return try cacheManager.loadOrganizations()
    }
    
    /// Load metadata cache
    public func loadMetadataFromCache() throws -> CapabilityMetadataCache? {
        return try cacheManager.loadMetadataCache()
    }
    
    // MARK: - Private Methods
    
    private func createDirectoryStructure() throws {
        let directories = [
            capabilitiesDirectory,
            repositoryDirectory,
            cacheDirectory,
            configDirectory
        ]
        
        for directory in directories {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    private func setupDatabase() throws {
        database = try Connection(databasePath.path)
        try createTables()
        try createIndexes()
    }
    
    private func createTables() throws {
        guard let db = database else { return }
        
        // Organizations table
        try db.run(organizations.create(ifNotExists: true) { table in
            table.column(orgId, primaryKey: true)
            table.column(orgName)
            table.column(orgDescription)
            table.column(orgLogoUrl)
            table.column(orgIsInstalled, defaultValue: false)
            table.column(orgIsLocalOnly, defaultValue: false)
            table.column(orgCreatedAt)
            table.column(orgUpdatedAt)
            table.column(orgMetadataJson)
        })
        
        // Capabilities table
        try db.run(capabilities.create(ifNotExists: true) { table in
            table.column(capId, primaryKey: true)
            table.column(capName)
            table.column(capOrgId)
            table.column(capDescription)
            table.column(capType)
            table.column(capEntryPoint)
            table.column(capFilePath)
            // Columns that don't exist in actual database are commented out
            // table.column(capLogoUrl)
            // table.column(capIsInstalled, defaultValue: false)
            // table.column(capVersion)
            // table.column(capCreatedAt)
            // table.column(capLastExecutedAt)
            // table.column(capExecutionCount, defaultValue: 0)
            // table.column(capTags)
            // table.column(capMetadataJson)
            table.column(capInputs)
            table.column(capOutputs)
            table.column(capAuthType)
            table.column(capInstalledAt)
            table.foreignKey(capOrgId, references: organizations, orgId, delete: .cascade)
        })
        
        // Parameters table
        try db.run(capabilityParameters.create(ifNotExists: true) { table in
            table.column(paramId, primaryKey: .autoincrement)
            table.column(paramCapId)
            table.column(paramName)
            table.column(paramType)
            table.column(paramRequired)
            table.column(paramDescription)
            table.column(paramDefaultValue)
            table.foreignKey(paramCapId, references: capabilities, capId, delete: .cascade)
        })
        
        // Installations table
        try db.run(installations.create(ifNotExists: true) { table in
            table.column(instCapId, primaryKey: true)
            table.column(instInstalledAt)
            table.column(instSource)
            table.column(instMetadata)
            table.foreignKey(instCapId, references: capabilities, capId, delete: .cascade)
        })
        
        // Usage table
        try db.run(capabilityUsage.create(ifNotExists: true) { table in
            table.column(usageId, primaryKey: .autoincrement)
            table.column(usageCapId)
            table.column(usageExecutedAt)
            table.column(usageExecutionTime)
            table.column(usageSuccess)
            table.column(usageErrorMessage)
            table.column(usageParametersJson)
            table.foreignKey(usageCapId, references: capabilities, capId, delete: .cascade)
        })
    }
    
    private func createIndexes() throws {
        guard let db = database else { return }
        
        // Performance indexes
        try db.run("CREATE INDEX IF NOT EXISTS idx_capabilities_org ON capabilities(organization_id)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_capabilities_type ON capabilities(type)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_usage_capability_time ON capability_usage(capability_id, executed_at)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_parameters_capability ON capability_parameters(capability_id)")
    }
    
    private func parseCapabilityMetadata(from row: Row) throws -> DarwinCapabilityMetadata {
        // Construct from individual columns
        let inputs: [DarwinFunctionParameter] = [] // TODO: Parse from parameters table
        let output = DarwinCapabilityOutput(type: "string", description: "Capability output")
        
        return DarwinCapabilityMetadata(
            type: row[capType],
            name: row[capName],
            description: row[capDescription] ?? "",
            entry_point: row[capEntryPoint] ?? "",
            organization: row[capOrgId],
            inputs: inputs,
            output: output,
            auth_type: .none
        )
    }
}
