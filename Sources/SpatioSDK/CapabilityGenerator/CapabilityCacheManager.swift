import Foundation

/// Cache manager for fast capability loading and search
/// Extracted and adapted from Darwin AI's CapabilityCacheManager.swift
public class CapabilityCacheManager {
    
    // MARK: - Properties
    
    private let cacheDirectory: URL
    private let installedCacheFile: URL
    private let searchIndexFile: URL
    private let organizationsCacheFile: URL
    private let metadataCacheFile: URL
    private let persistenceLayer: PersistenceLayer
    
    // MARK: - Initialization
    
    public init(cacheDirectory: URL, persistenceLayer: PersistenceLayer) {
        self.cacheDirectory = cacheDirectory
        self.persistenceLayer = persistenceLayer
        self.installedCacheFile = cacheDirectory.appendingPathComponent("installed.json")
        self.searchIndexFile = cacheDirectory.appendingPathComponent("search_index.json")
        self.organizationsCacheFile = cacheDirectory.appendingPathComponent("organizations.json")
        self.metadataCacheFile = cacheDirectory.appendingPathComponent("metadata.json")
        
        // Ensure cache directory exists
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    // MARK: - Cache Generation
    
    /// Generate cache for installed capabilities
    public func refreshInstalledCache() throws {
        let installedCapabilities = try getAllInstalledCapabilities()
        
        let cacheData = InstalledCapabilitiesCache(
            generated: Date(),
            version: "1.0.0",
            count: installedCapabilities.count,
            capabilities: installedCapabilities.map { capability in
                InstalledCapabilityItem(
                    id: generateCapabilityId(from: capability.name),
                    name: capability.name,
                    organization: capability.organization,
                    group: capability.group,
                    description: capability.description,
                    type: capability.type,
                    entryPoint: capability.entry_point,
                    categories: [], // TODO: Add categories support
                    tags: [] // TODO: Add tags support
                )
            }
        )
        
        try saveCache(data: cacheData, to: installedCacheFile)
    }
    
    /// Generate search index for fast capability search
    public func refreshSearchIndex() throws {
        let allCapabilities = try getAllCapabilities()
        
        let searchIndex = CapabilitySearchIndex(
            generated: Date(),
            version: "1.0.0",
            totalCapabilities: allCapabilities.count,
            index: allCapabilities.map { capability in
                SearchIndexItem(
                    id: generateCapabilityId(from: capability.name),
                    name: capability.name,
                    description: capability.description,
                    organization: capability.organization,
                    group: capability.group,
                    categories: [], // TODO: Add categories support
                    tags: [], // TODO: Add tags support
                    searchTerms: generateSearchTerms(for: capability)
                )
            }
        )
        
        try saveCache(data: searchIndex, to: searchIndexFile)
    }
    
    /// Generate organizations cache
    public func refreshOrganizationsCache() throws {
        let organizations = try persistenceLayer.listOrganizations()
        
        let orgCache = OrganizationsCache(
            generated: Date(),
            version: "1.0.0",
            count: organizations.count,
            organizations: organizations.map { org in
                CachedOrganization(
                    id: org.id,
                    name: org.name,
                    description: org.description,
                    logoUrl: org.logo,
                    isLocalOnly: org.types?.contains("local") == true,
                    capabilityCount: getCapabilityCount(for: org.id)
                )
            }
        )
        
        try saveCache(data: orgCache, to: organizationsCacheFile)
    }
    
    /// Generate comprehensive metadata cache
    public func refreshMetadataCache() throws {
        let allCapabilities = try getAllCapabilities()
        let organizations = try persistenceLayer.listOrganizations()
        let groups: [CachedGroup] = [] // TODO: Add groups support
        
        let metadataCache = CapabilityMetadataCache(
            generated: Date(),
            version: "1.0.0",
            statistics: CacheStatistics(
                totalCapabilities: allCapabilities.count,
                totalOrganizations: organizations.count,
                totalGroups: groups.count,
                installedCapabilities: allCapabilities.count // All capabilities in this context are installed
            ),
            organizations: organizations.map { org in
                CachedOrganization(
                    id: org.id,
                    name: org.name,
                    description: org.description,
                    logoUrl: org.logo,
                    isLocalOnly: org.types?.contains("local") == true,
                    capabilityCount: getCapabilityCount(for: org.id)
                )
            },
            groups: groups,
            capabilities: allCapabilities.map { capability in
                CachedCapabilityMetadata(
                    id: generateCapabilityId(from: capability.name),
                    name: capability.name,
                    organization: capability.organization,
                    group: capability.group,
                    description: capability.description,
                    type: capability.type,
                    isInstalled: true, // All capabilities in this context are installed
                    lastUpdated: Date(),
                    categories: [], // TODO: Add categories support
                    tags: [] // TODO: Add tags support
                )
            }
        )
        
        try saveCache(data: metadataCache, to: metadataCacheFile)
    }
    
    /// Refresh all caches
    public func refreshAllCaches() throws {
        try refreshInstalledCache()
        try refreshSearchIndex()
        try refreshOrganizationsCache()
        try refreshMetadataCache()
        
        Logger.shared.info("All caches refreshed")
    }
    
    // MARK: - Cache Loading
    
    /// Load installed capabilities from cache
    public func loadInstalledCapabilities() throws -> InstalledCapabilitiesCache? {
        return try loadCache(from: installedCacheFile, as: InstalledCapabilitiesCache.self)
    }
    
    /// Load search index from cache
    public func loadSearchIndex() throws -> CapabilitySearchIndex? {
        return try loadCache(from: searchIndexFile, as: CapabilitySearchIndex.self)
    }
    
    /// Load organizations from cache
    public func loadOrganizations() throws -> OrganizationsCache? {
        return try loadCache(from: organizationsCacheFile, as: OrganizationsCache.self)
    }
    
    /// Load metadata cache
    public func loadMetadataCache() throws -> CapabilityMetadataCache? {
        return try loadCache(from: metadataCacheFile, as: CapabilityMetadataCache.self)
    }
    
    // MARK: - Cache Validation
    
    /// Check if cache is valid (not older than specified time)
    public func isCacheValid(file: URL, maxAge: TimeInterval = 3600) -> Bool {
        guard FileManager.default.fileExists(atPath: file.path) else { return false }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                return Date().timeIntervalSince(modificationDate) < maxAge
            }
        } catch {
            Logger.shared.error("Error checking cache validity: \(error)")
        }
        
        return false
    }
    
    /// Clear all cache files
    public func clearAllCaches() throws {
        let cacheFiles = [
            installedCacheFile,
            searchIndexFile,
            organizationsCacheFile,
            metadataCacheFile
        ]
        
        for file in cacheFiles {
            try? FileManager.default.removeItem(at: file)
        }
        
        Logger.shared.info("All caches cleared")
    }
    
    // MARK: - Helper Methods
    
    private func saveCache<T: Codable>(data: T, to file: URL) throws {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try jsonEncoder.encode(data)
        try jsonData.write(to: file)
        Logger.shared.debug("Cache saved: \(file.lastPathComponent)")
    }
    
    private func loadCache<T: Codable>(from file: URL, as type: T.Type) throws -> T? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        
        let data = try Data(contentsOf: file)
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        
        let cache = try jsonDecoder.decode(type, from: data)
        return cache
    }
    
    private func getAllCapabilities() throws -> [DarwinCapabilityMetadata] {
        let organizations = try persistenceLayer.listOrganizations()
        var allCapabilities: [DarwinCapabilityMetadata] = []
        
        for org in organizations {
            let orgCapabilities = try persistenceLayer.listCapabilities(for: org.id)
            allCapabilities.append(contentsOf: orgCapabilities)
        }
        
        return allCapabilities
    }
    
    private func getAllInstalledCapabilities() throws -> [DarwinCapabilityMetadata] {
        // Since we're using PersistenceLayer, all capabilities are considered installed
        return try getAllCapabilities()
    }
    
    private func getCapabilityCount(for organizationId: String) -> Int {
        do {
            let capabilities = try persistenceLayer.listCapabilities(for: organizationId)
            return capabilities.count
        } catch {
            Logger.shared.error("Error counting capabilities for \(organizationId): \(error)")
            return 0
        }
    }
    
    private func generateCapabilityId(from name: String) -> String {
        return name.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "/", with: "_")
    }
    
    private func generateSearchTerms(for capability: DarwinCapabilityMetadata) -> [String] {
        var terms: [String] = []
        
        // Add name words
        terms.append(contentsOf: capability.name.components(separatedBy: .whitespacesAndNewlines))
        
        // Add description words
        terms.append(contentsOf: capability.description.components(separatedBy: .whitespacesAndNewlines))
        
        // Add organization and group
        terms.append(capability.organization)
        terms.append(capability.group)
        
        // Add type
        terms.append(capability.type)
        
        // Add parameter names for searchability
        terms.append(contentsOf: capability.inputs.map { $0.name })
        
        // Clean and deduplicate
        return Array(Set(terms.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }))
            .filter { !$0.isEmpty }
    }
}

// MARK: - Cache Data Structures

public struct InstalledCapabilitiesCache: Codable {
    public let generated: Date
    public let version: String
    public let count: Int
    public let capabilities: [InstalledCapabilityItem]
}

public struct InstalledCapabilityItem: Codable {
    public let id: String
    public let name: String
    public let organization: String
    public let group: String?
    public let description: String
    public let type: String
    public let entryPoint: String?
    public let categories: [String]
    public let tags: [String]
}

public struct CapabilitySearchIndex: Codable {
    public let generated: Date
    public let version: String
    public let totalCapabilities: Int
    public let index: [SearchIndexItem]
}

public struct SearchIndexItem: Codable {
    public let id: String
    public let name: String
    public let description: String
    public let organization: String
    public let group: String?
    public let categories: [String]
    public let tags: [String]
    public let searchTerms: [String]
}

public struct OrganizationsCache: Codable {
    public let generated: Date
    public let version: String
    public let count: Int
    public let organizations: [CachedOrganization]
}

public struct CachedOrganization: Codable {
    public let id: String
    public let name: String
    public let description: String?
    public let logoUrl: String?
    public let isLocalOnly: Bool
    public let capabilityCount: Int
}

public struct CachedGroup: Codable {
    public let id: String
    public let organizationId: String
    public let name: String
    public let description: String?
    public let logoUrl: String?
    public let capabilityCount: Int
}

public struct CapabilityMetadataCache: Codable {
    public let generated: Date
    public let version: String
    public let statistics: CacheStatistics
    public let organizations: [CachedOrganization]
    public let groups: [CachedGroup]
    public let capabilities: [CachedCapabilityMetadata]
}

public struct CacheStatistics: Codable {
    public let totalCapabilities: Int
    public let totalOrganizations: Int
    public let totalGroups: Int
    public let installedCapabilities: Int
}

public struct CachedCapabilityMetadata: Codable {
    public let id: String
    public let name: String
    public let organization: String
    public let group: String?
    public let description: String
    public let type: String
    public let isInstalled: Bool
    public let lastUpdated: Date
    public let categories: [String]
    public let tags: [String]
}