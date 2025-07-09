//
//  RemotePersistenceLayer.swift
//  SpatioSDK
//
//  Extracted and adapted from Darwin AI's SQLiteStoreClient.swift
//

import Foundation
import SQLite3

/// Remote persistence layer implementation for capabilities-store SQLite database
/// Extracted and adapted from Darwin AI's SQLiteStoreClient.swift
public class RemotePersistenceLayer: PersistenceLayer {
    
    // MARK: - PersistenceLayer Protocol
    
    public let mode: PersistenceMode
    
    // MARK: - Database Connection
    private var db: OpaquePointer?
    private var isConnected = false
    private var databasePath: String?
    private let capabilitiesStorePath: String
    
    // MARK: - Cache Manager
    private let cacheManager: CapabilityCacheManager
    
    // MARK: - Performance Metrics
    private var totalQueries = 0
    private var averageQueryTime: TimeInterval = 0
    private var lastQueryTime: TimeInterval = 0
    private var queryTimes: [TimeInterval] = []
    
    // MARK: - Initialization
    
    public init(capabilitiesStorePath: String) throws {
        self.capabilitiesStorePath = capabilitiesStorePath
        self.mode = .remote(path: capabilitiesStorePath)
        
        // Set up cache directory
        let cacheDir = URL(fileURLWithPath: capabilitiesStorePath).appendingPathComponent("cache")
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        // Initialize cache manager
        cacheManager = CapabilityCacheManager(cacheDirectory: cacheDir, persistenceLayer: self)
        
        Logger.shared.info("RemotePersistenceLayer initialized for path: \(capabilitiesStorePath)")
    }
    
    // MARK: - PersistenceLayer Implementation
    
    public func createOrganization(
        _ organization: DarwinOrganizationData,
        overwrite: Bool
    ) throws {
        throw PersistenceError.operationNotSupported("Remote persistence layer is read-only")
    }
    
    public func createCapability(
        _ capability: DarwinCapabilityMetadata,
        overwrite: Bool
    ) throws {
        throw PersistenceError.operationNotSupported("Remote persistence layer is read-only")
    }
    
    public func listOrganizations() throws -> [DarwinOrganizationData] {
        return try withConnection { db in
            let sql = """
                SELECT id, name, description, logo, path, url, parent_id, children, tags, created_at
                FROM organizations
                WHERE 1=1
                ORDER BY name ASC
            """
            
            let organizations = try executeQuery(sql: sql, parameters: []) { stmt in
                return RemoteOrganization(
                    id: String(cString: sqlite3_column_text(stmt, 0)),
                    name: String(cString: sqlite3_column_text(stmt, 1)),
                    description: String(cString: sqlite3_column_text(stmt, 2)),
                    logo: sqlite3_column_text(stmt, 3) != nil ? String(cString: sqlite3_column_text(stmt, 3)) : nil,
                    path: String(cString: sqlite3_column_text(stmt, 4)),
                    url: String(cString: sqlite3_column_text(stmt, 5)),
                    parentId: sqlite3_column_text(stmt, 6) != nil ? String(cString: sqlite3_column_text(stmt, 6)) : nil,
                    children: parseJSONArray(UnsafeRawPointer(sqlite3_column_text(stmt, 7))?.assumingMemoryBound(to: CChar.self)),
                    tags: parseJSONArray(UnsafeRawPointer(sqlite3_column_text(stmt, 8))?.assumingMemoryBound(to: CChar.self)),
                    createdAt: parseDate(UnsafeRawPointer(sqlite3_column_text(stmt, 9))?.assumingMemoryBound(to: CChar.self))
                )
            }
            
            return organizations.map { $0.toDarwinOrganizationData() }
        }
    }
    
    public func listCapabilities(for organizationId: String) throws -> [DarwinCapabilityMetadata] {
        return try withConnection { db in
            // Get the organization and its children
            var children: [String] = []
            let orgSql = "SELECT children FROM organizations WHERE id = ? LIMIT 1"
            
            let orgResults = try executeQuery(sql: orgSql, parameters: [organizationId]) { stmt in
                let childrenText = sqlite3_column_text(stmt, 0)
                if childrenText != nil {
                    return parseJSONArray(UnsafeRawPointer(childrenText)?.assumingMemoryBound(to: CChar.self))
                } else {
                    return []
                }
            }
            
            if let firstResult = orgResults.first {
                children = firstResult
            }
            
            // Build list of valid organization IDs (root org + children)
            var validOrgIds = [organizationId]
            validOrgIds.append(contentsOf: children)
            
            // Build SQL to find capabilities that belong to any of the valid organization IDs
            let placeholders = validOrgIds.map { _ in "?" }.joined(separator: ", ")
            let sql = """
                SELECT id, name, title, description, logo, organization_id, group_id, group_name,
                       items, api_schema, auth_flow, examples, relationships, path, url, tags, categories, entry_point, type, created_at
                FROM capabilities
                WHERE organization_id IN (\(placeholders))
                ORDER BY name ASC
            """
            
            let capabilities = try executeQuery(sql: sql, parameters: validOrgIds) { stmt in
                return parseCapabilityFromStatement(stmt)
            }
            
            return capabilities.map { $0.toDarwinCapabilityMetadata() }
        }
    }
    
    public func removeOrganization(organizationId: String) throws {
        throw PersistenceError.operationNotSupported("Remote persistence layer is read-only")
    }
    
    public func removeCapability(
        capabilityName: String,
        from organizationId: String
    ) throws {
        throw PersistenceError.operationNotSupported("Remote persistence layer is read-only")
    }
    
    public func organizationExists(organizationId: String) -> Bool {
        do {
            return try withConnection { db in
                let sql = "SELECT COUNT(*) FROM organizations WHERE id = ? LIMIT 1"
                let count = try executeScalarQuery(sql: sql, parameters: [organizationId])
                return count > 0
            }
        } catch {
            return false
        }
    }
    
    public func capabilityExists(
        capabilityName: String,
        in organizationId: String
    ) -> Bool {
        do {
            return try withConnection { db in
                let sql = "SELECT COUNT(*) FROM capabilities WHERE name = ? AND organization_id = ? LIMIT 1"
                let count = try executeScalarQuery(sql: sql, parameters: [capabilityName, organizationId])
                return count > 0
            }
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
    
    // MARK: - Database Management
    
    /// Download and connect to the SQLite database
    public func connectToDatabase() async throws {
        guard !isConnected else { return }
        
        // Use the download-changes API to get the SQLite database
        let localPath = try await downloadDatabaseViaAPI()
        
        // Connect to the local database
        try connectToLocalDatabase(at: localPath)
        
        Logger.shared.info("RemotePersistenceLayer connected to database at: \(localPath)")
    }
    
    /// Download the SQLite database file via the authenticated download-changes API
    private func downloadDatabaseViaAPI() async throws -> String {
        let cacheDir = URL(fileURLWithPath: capabilitiesStorePath).appendingPathComponent("cache/apps/app-store")
        
        // Create cache directory if it doesn't exist
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        
        let localFile = cacheDir.appendingPathComponent("capabilities.sqlite")
        
        // Check if we already have a recent version
        if FileManager.default.fileExists(atPath: localFile.path) {
            let attributes = try FileManager.default.attributesOfItem(atPath: localFile.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                let hoursSinceModification = Date().timeIntervalSince(modificationDate) / 3600
                if hoursSinceModification < 24 { // Use cached version if less than 24 hours old
                    Logger.shared.info("Using existing SQLite database at: \(localFile.path) (modified \(String(format: "%.1f", hoursSinceModification)) hours ago)")
                    return localFile.path
                }
            }
        }
        
        Logger.shared.info("Downloading SQLite database via download-changes API...")
        
        // Use the download-changes API endpoint
        guard let url = URL(string: "https://spatiolabs.org/api/capabilities/download-changes") else {
            throw PersistenceError.databaseError("Invalid URL")
        }
        
        let requestBody: [String: Any] = [
            "repository": "capabilities-store"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add license key if available (this would need to be injected)
        // request.setValue(licenseKey, forHTTPHeaderField: "x-license-key")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PersistenceError.databaseError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PersistenceError.databaseError("Download-changes API returned status: \(httpResponse.statusCode)")
        }
        
        // Parse the response to get the base64-encoded database
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let base64Database = json["database"] as? String else {
            throw PersistenceError.databaseError("No database field found in download-changes response")
        }
        
        // Decode the base64 data
        guard let databaseData = Data(base64Encoded: base64Database) else {
            throw PersistenceError.databaseError("Failed to decode base64 database data")
        }
        
        // Write the database file
        try databaseData.write(to: localFile)
        
        Logger.shared.info("Downloaded SQLite database: \(databaseData.count) bytes to: \(localFile.path)")
        return localFile.path
    }
    
    /// Connect to a local SQLite database file
    private func connectToLocalDatabase(at path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw PersistenceError.databaseError("Connection failed: \(errorMessage)")
        }
        
        databasePath = path
        isConnected = true
        
        // Enable foreign keys
        try executeSQL("PRAGMA foreign_keys = ON")
        
        // Optimize for read performance
        try executeSQL("PRAGMA journal_mode = WAL")
        try executeSQL("PRAGMA synchronous = NORMAL")
        try executeSQL("PRAGMA cache_size = 10000")
        try executeSQL("PRAGMA temp_store = MEMORY")
    }
    
    /// Disconnect from the database
    public func disconnect() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
        isConnected = false
        databasePath = nil
    }
    
    // MARK: - Private Helper Methods
    
    private func withConnection<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        guard let db = db, isConnected else {
            throw PersistenceError.databaseError("Database not connected")
        }
        return try operation(db)
    }
    
    private func executeSQL(_ sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw PersistenceError.databaseError("Execution failed: \(errorMessage)")
        }
    }
    
    private func executeQuery<T>(sql: String, parameters: [String], mapper: (OpaquePointer) -> T) throws -> [T] {
        let startTime = Date()
        var stmt: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw PersistenceError.databaseError("Preparation failed: \(errorMessage)")
        }
        
        defer {
            sqlite3_finalize(stmt)
        }
        
        // Bind parameters
        for (index, parameter) in parameters.enumerated() {
            let result = sqlite3_bind_text(stmt, Int32(index + 1), parameter, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            if result != SQLITE_OK {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                throw PersistenceError.databaseError("Parameter binding failed: \(errorMessage)")
            }
        }
        
        var results: [T] = []
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(mapper(stmt!))
        }
        
        recordQueryTime(Date().timeIntervalSince(startTime))
        return results
    }
    
    private func executeScalarQuery(sql: String, parameters: [String]) throws -> Int {
        let startTime = Date()
        var stmt: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw PersistenceError.databaseError("Preparation failed: \(errorMessage)")
        }
        
        defer {
            sqlite3_finalize(stmt)
        }
        
        // Bind parameters
        for (index, parameter) in parameters.enumerated() {
            let result = sqlite3_bind_text(stmt, Int32(index + 1), parameter, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            if result != SQLITE_OK {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                throw PersistenceError.databaseError("Parameter binding failed: \(errorMessage)")
            }
        }
        
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            recordQueryTime(Date().timeIntervalSince(startTime))
            return 0
        }
        
        let result = Int(sqlite3_column_int(stmt, 0))
        recordQueryTime(Date().timeIntervalSince(startTime))
        return result
    }
    
    private func parseCapabilityFromStatement(_ stmt: OpaquePointer) -> RemoteCapability {
        return RemoteCapability(
            id: String(cString: sqlite3_column_text(stmt, 0)),
            name: String(cString: sqlite3_column_text(stmt, 1)),
            title: String(cString: sqlite3_column_text(stmt, 2)),
            description: String(cString: sqlite3_column_text(stmt, 3)),
            logo: sqlite3_column_text(stmt, 4) != nil ? String(cString: sqlite3_column_text(stmt, 4)) : nil,
            organizationId: String(cString: sqlite3_column_text(stmt, 5)),
            groupId: sqlite3_column_text(stmt, 6) != nil ? String(cString: sqlite3_column_text(stmt, 6)) : nil,
            groupName: String(cString: sqlite3_column_text(stmt, 7)),
            items: parseJSONArray(UnsafeRawPointer(sqlite3_column_text(stmt, 8))?.assumingMemoryBound(to: CChar.self)),
            apiSchema: parseAPISchema(UnsafeRawPointer(sqlite3_column_text(stmt, 9))?.assumingMemoryBound(to: CChar.self)),
            authFlow: sqlite3_column_text(stmt, 10) != nil ? String(cString: sqlite3_column_text(stmt, 10)) : nil,
            examples: parseJSONArray(UnsafeRawPointer(sqlite3_column_text(stmt, 11))?.assumingMemoryBound(to: CChar.self)),
            relationships: parseJSONArray(UnsafeRawPointer(sqlite3_column_text(stmt, 12))?.assumingMemoryBound(to: CChar.self)),
            path: String(cString: sqlite3_column_text(stmt, 13)),
            url: String(cString: sqlite3_column_text(stmt, 14)),
            tags: parseJSONArray(UnsafeRawPointer(sqlite3_column_text(stmt, 15))?.assumingMemoryBound(to: CChar.self)),
            categories: parseJSONArray(UnsafeRawPointer(sqlite3_column_text(stmt, 16))?.assumingMemoryBound(to: CChar.self)),
            entryPoint: String(cString: sqlite3_column_text(stmt, 17)),
            type: String(cString: sqlite3_column_text(stmt, 18)),
            createdAt: parseDate(UnsafeRawPointer(sqlite3_column_text(stmt, 19))?.assumingMemoryBound(to: CChar.self))
        )
    }
    
    private func parseJSONArray(_ text: UnsafePointer<CChar>?) -> [String] {
        guard let text = text else { 
            return [] 
        }
        let jsonString = String(cString: text)
        
        // Handle null values
        if jsonString == "null" || jsonString.isEmpty {
            return []
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            return []
        }
        
        do {
            guard let array = try JSONSerialization.jsonObject(with: data) as? [String] else {
                return []
            }
            return array
        } catch {
            Logger.shared.error("parseJSONArray - JSON parsing error for '\(jsonString)': \(error)")
            return []
        }
    }
    
    private func parseAPISchema(_ text: UnsafePointer<CChar>?) -> RemoteAPISchema? {
        guard let text = text else { return nil }
        let jsonString = String(cString: text)
        guard let data = jsonString.data(using: .utf8),
              let schema = try? JSONDecoder().decode(RemoteAPISchema.self, from: data) else {
            return nil
        }
        return schema
    }
    
    private func parseDate(_ text: UnsafePointer<CChar>?) -> Date {
        guard let text = text else { return Date() }
        let dateString = String(cString: text)
        
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString) ?? Date()
    }
    
    private func recordQueryTime(_ time: TimeInterval) {
        totalQueries += 1
        lastQueryTime = time
        queryTimes.append(time)
        
        // Keep only last 100 query times for average calculation
        if queryTimes.count > 100 {
            queryTimes.removeFirst()
        }
        
        averageQueryTime = queryTimes.reduce(0, +) / Double(queryTimes.count)
    }
}

// MARK: - Remote Data Models

struct RemoteOrganization {
    let id: String
    let name: String
    let description: String
    let logo: String?
    let path: String
    let url: String
    let parentId: String?
    let children: [String]
    let tags: [String]
    let createdAt: Date
    
    func toDarwinOrganizationData() -> DarwinOrganizationData {
        return DarwinOrganizationData(
            id: id,
            name: name,
            description: description,
            logo: logo,
            types: parentId != nil ? ["nested"] : ["root"],
            tags: tags.isEmpty ? nil : tags
        )
    }
}

struct RemoteCapability {
    let id: String
    let name: String
    let title: String
    let description: String
    let logo: String?
    let organizationId: String
    let groupId: String?
    let groupName: String
    let items: [String]
    let apiSchema: RemoteAPISchema?
    let authFlow: String?
    let examples: [String]
    let relationships: [String]
    let path: String
    let url: String
    let tags: [String]
    let categories: [String]
    let entryPoint: String
    let type: String
    let createdAt: Date
    
    func toDarwinCapabilityMetadata() -> DarwinCapabilityMetadata {
        let inputs: [DarwinFunctionParameter] = [] // TODO: Parse from apiSchema
        let output = DarwinCapabilityOutput(type: "string", description: "Capability output")
        
        return DarwinCapabilityMetadata(
            type: type,
            name: name,
            description: description,
            entry_point: entryPoint,
            organization: organizationId,
            group: groupId ?? groupName,
            inputs: inputs,
            output: output,
            auth_type: .none
        )
    }
}

struct RemoteAPISchema: Codable {
    let inputs: [String: Any]?
    let output: [String: Any]?
    let auth: [String: Any]?
    let entryPoint: String?
    
    // Custom coding to handle Any types
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let inputsData = try? container.decode(Data.self, forKey: .inputs) {
            inputs = try? JSONSerialization.jsonObject(with: inputsData) as? [String: Any]
        } else {
            inputs = nil
        }
        
        if let outputData = try? container.decode(Data.self, forKey: .output) {
            output = try? JSONSerialization.jsonObject(with: outputData) as? [String: Any]
        } else {
            output = nil
        }
        
        if let authData = try? container.decode(Data.self, forKey: .auth) {
            auth = try? JSONSerialization.jsonObject(with: authData) as? [String: Any]
        } else {
            auth = nil
        }
        
        entryPoint = try? container.decode(String.self, forKey: .entryPoint)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if let inputs = inputs {
            let data = try JSONSerialization.data(withJSONObject: inputs)
            try container.encode(data, forKey: .inputs)
        }
        
        if let output = output {
            let data = try JSONSerialization.data(withJSONObject: output)
            try container.encode(data, forKey: .output)
        }
        
        if let auth = auth {
            let data = try JSONSerialization.data(withJSONObject: auth)
            try container.encode(data, forKey: .auth)
        }
        
        try container.encodeIfPresent(entryPoint, forKey: .entryPoint)
    }
    
    private enum CodingKeys: String, CodingKey {
        case inputs, output, auth, entryPoint
    }
}