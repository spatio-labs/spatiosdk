import Foundation
import SQLite3

/// Darwin AI native persistence layer implementation
/// Uses Darwin AI's exact database schema for direct compatibility
public class DarwinPersistenceLayer: PersistenceLayer {
    
    // MARK: - PersistenceLayer Protocol
    
    public let mode: PersistenceMode = .darwin
    
    // MARK: - Properties
    
    /// SQLite database connection
    private var db: OpaquePointer?
    
    /// Path to the Darwin AI store directory
    private let storeDirectory: URL
    
    /// Path to the repository subdirectory
    private let repositoryDirectory: URL
    
    /// Path to the SQLite database
    private let databasePath: URL
    
    /// JSON encoder for metadata
    private let jsonEncoder = JSONEncoder()
    
    /// JSON decoder for metadata
    private let jsonDecoder = JSONDecoder()
    
    // MARK: - Initialization
    
    public init() throws {
        // Set up paths
        self.storeDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".darwin")
            .appendingPathComponent("store")
        
        self.repositoryDirectory = storeDirectory.appendingPathComponent("repository")
        self.databasePath = storeDirectory.appendingPathComponent("installed.db")
        
        // Create directories if needed
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: repositoryDirectory, withIntermediateDirectories: true)
        
        // Initialize database
        try initializeDatabase()
    }
    
    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }
    
    // MARK: - Database Initialization
    
    private func initializeDatabase() throws {
        // Open database
        if sqlite3_open(databasePath.path, &db) != SQLITE_OK {
            throw PersistenceError.databaseError("Unable to open database at \(databasePath.path)")
        }
        
        // Create tables if they don't exist
        try createTables()
    }
    
    private func createTables() throws {
        // Note: The organizations table is created by LocalPersistenceLayer
        // We don't create it here to avoid duplication
        
        // Create capabilities table (Darwin AI's exact schema)
        let createCapabilitiesTable = """
            CREATE TABLE IF NOT EXISTS capabilities (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT,
                type TEXT,
                organization_id TEXT NOT NULL,
                entry_point TEXT,
                inputs TEXT,
                outputs TEXT,
                auth_type TEXT,
                installed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                path TEXT NOT NULL,
                FOREIGN KEY (organization_id) REFERENCES organizations(id)
            );
        """
        
        // Create installation_metadata table
        let createMetadataTable = """
            CREATE TABLE IF NOT EXISTS installation_metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );
        """
        
        // Execute table creation
        // Note: organizations table is managed by LocalPersistenceLayer
        try executeSQL(createCapabilitiesTable)
        try executeSQL(createMetadataTable)
        
        // Create indexes for better performance
        try executeSQL("CREATE INDEX IF NOT EXISTS idx_capabilities_org ON capabilities(organization_id);")
        // Note: indexes for organizations table are managed by LocalPersistenceLayer
    }
    
    private func executeSQL(_ sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw PersistenceError.databaseError("SQL error: \(errmsg)")
        }
    }
    
    // MARK: - PersistenceLayer Methods
    
    public func createOrganization(
        _ organization: DarwinOrganizationData,
        overwrite: Bool
    ) throws {
        if !overwrite && organizationExists(organizationId: organization.id) {
            throw PersistenceError.organizationExists(organization.id)
        }
        
        // Create organization directory
        let orgDir = repositoryDirectory.appendingPathComponent(organization.id)
        try FileManager.default.createDirectory(at: orgDir, withIntermediateDirectories: true)
        
        // Create org.json file in the organization directory
        let orgJsonPath = orgDir.appendingPathComponent("org.json")
        let orgJsonData = try jsonEncoder.encode(organization)
        try orgJsonData.write(to: orgJsonPath)
        
        // Insert into database
        // Convert to LocalPersistenceLayer schema format
        let metadata: [String: Any] = [
            "types": organization.types ?? [],
            "tags": organization.tags ?? [],
            "path": orgDir.path,
            "pngLogo": organization.pngLogo as Any,
            "svgLogo": organization.svgLogo as Any
        ]
        let metadataJson = try JSONSerialization.data(withJSONObject: metadata)
        let metadataString = String(data: metadataJson, encoding: .utf8) ?? "{}"
        
        let query = """
            INSERT OR \(overwrite ? "REPLACE" : "ABORT") INTO organizations
            (id, name, description, logo_url, is_installed, is_local_only, created_at, updated_at, metadata_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        defer {
            if statement != nil {
                sqlite3_finalize(statement)
            }
        }
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            let currentTime = Int64(Date().timeIntervalSince1970)
            
            sqlite3_bind_text(statement, 1, organization.id, -1, nil)
            sqlite3_bind_text(statement, 2, organization.name, -1, nil)
            sqlite3_bind_text(statement, 3, organization.description, -1, nil)
            
            if let logo = organization.logo {
                sqlite3_bind_text(statement, 4, logo, -1, nil)
            } else {
                sqlite3_bind_null(statement, 4)
            }
            
            sqlite3_bind_int(statement, 5, 1) // is_installed = true
            sqlite3_bind_int(statement, 6, 0) // is_local_only = false
            sqlite3_bind_int64(statement, 7, currentTime) // created_at
            sqlite3_bind_int64(statement, 8, currentTime) // updated_at
            sqlite3_bind_text(statement, 9, metadataString, -1, nil) // metadata_json
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db))
                throw PersistenceError.databaseError("Failed to insert organization: \(errmsg)")
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw PersistenceError.databaseError("Failed to prepare organization insert: \(errmsg)")
        }
        
        Logger.shared.info("Created organization: \(organization.id)")
    }
    
    public func createCapability(
        _ capability: DarwinCapabilityMetadata,
        overwrite: Bool
    ) throws {
        let capabilityId = "\(capability.organization).\(capability.name)"
        
        if !overwrite && capabilityExists(capabilityName: capability.name, in: capability.organization) {
            throw PersistenceError.capabilityExists(capability.name)
        }
        
        // Ensure organization exists
        if !organizationExists(organizationId: capability.organization) {
            throw PersistenceError.organizationNotFound(capability.organization)
        }
        
        // Create capability directory with kebab-case name
        let capabilityDirName = capability.name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        
        let capDir = repositoryDirectory
            .appendingPathComponent(capability.organization)
            .appendingPathComponent(capabilityDirName)
        
        try FileManager.default.createDirectory(at: capDir, withIntermediateDirectories: true)
        
        // Create capability.json file
        let capJsonPath = capDir.appendingPathComponent("capability.json")
        let capJsonData = try jsonEncoder.encode(capability)
        try capJsonData.write(to: capJsonPath)
        
        // Create appropriate execution file based on type
        if capability.type == "function" {
            let mainSwiftPath = capDir.appendingPathComponent("main.swift")
            let mainSwiftContent = """
            //
            //  \(capability.entry_point).swift
            //  \(capability.name)
            //
            
            import Foundation
            
            /// \(capability.description)
            class \(capability.entry_point): Capability {
                
                override func execute(inputs: [String: Any]) async throws -> [String: Any] {
                    // TODO: Implement capability logic
                    return ["result": "Not implemented"]
                }
            }
            """
            try mainSwiftContent.write(to: mainSwiftPath, atomically: true, encoding: .utf8)
        } else if capability.type == "core" {
            // For core tools, create a built-in marker file
            let builtInMarkerPath = capDir.appendingPathComponent("BUILT_IN_CORE_TOOL")
            let markerContent = """
            This capability is built directly into Darwin AI.
            Entry Point: \(capability.entry_point ?? "N/A")
            Implementation: /darwinAI/Services/CoreTools/Capabilities/\(capability.entry_point ?? "Unknown").swift
            """
            try markerContent.write(to: builtInMarkerPath, atomically: true, encoding: .utf8)
            
            // Create a reference main.swift that indicates this is built-in
            let mainSwiftPath = capDir.appendingPathComponent("main.swift")
            let mainSwiftContent = """
            #!/usr/bin/swift
            //
            //  Core Tool: \(capability.name)
            //  Entry Point: \(capability.entry_point ?? "Unknown")
            //
            //  This is a built-in core capability of Darwin AI.
            //  The actual implementation is compiled into the Darwin AI application.
            //
            
            import Foundation
            
            // This capability is executed internally by Darwin AI
            // It cannot be run as a standalone script
            
            print("{")
            print("  \"error\": \"This is a built-in core tool that runs inside Darwin AI.\",")
            print("  \"type\": \"core\",")
            print("  \"name\": \"\(capability.name)\",")
            print("  \"entry_point\": \"\(capability.entry_point ?? "N/A")\"")
            print("}")
            """
            try mainSwiftContent.write(to: mainSwiftPath, atomically: true, encoding: .utf8)
            
            // Make the main.swift file executable
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: mainSwiftPath.path)
        }
        
        // Convert inputs/outputs to JSON strings for database
        let inputsData = try jsonEncoder.encode(capability.inputs)
        let inputsString = String(data: inputsData, encoding: .utf8) ?? "[]"
        
        let outputsData = try jsonEncoder.encode(capability.output)
        let outputsString = String(data: outputsData, encoding: .utf8) ?? "{}"
        
        // Insert into database
        let query = """
            INSERT OR \(overwrite ? "REPLACE" : "ABORT") INTO capabilities
            (id, name, description, type, organization_id, entry_point, path, installed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP);
        """
        
        var statement: OpaquePointer?
        defer {
            if statement != nil {
                sqlite3_finalize(statement)
            }
        }
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            let currentTime = Int(Date().timeIntervalSince1970)
            
            // Create metadata JSON
            let metadata: [String: Any] = [
                "inputs": capability.inputs.map { input in
                    ["name": input.name, "type": input.type, "required": input.required, "description": input.description ?? ""]
                },
                "output": ["type": capability.output.type, "description": capability.output.description ?? ""],
                "auth_type": capability.auth_type.rawValue
            ]
            let metadataData = try JSONSerialization.data(withJSONObject: metadata)
            let metadataString = String(data: metadataData, encoding: .utf8) ?? "{}"
            
            sqlite3_bind_text(statement, 1, capabilityId, -1, nil)
            sqlite3_bind_text(statement, 2, capability.name, -1, nil)
            sqlite3_bind_text(statement, 3, capability.description, -1, nil)
            sqlite3_bind_text(statement, 4, capability.type, -1, nil)
            sqlite3_bind_text(statement, 5, capability.organization, -1, nil)
            sqlite3_bind_text(statement, 6, capability.entry_point, -1, nil)
            sqlite3_bind_text(statement, 7, capDir.path, -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db))
                throw PersistenceError.databaseError("Failed to insert capability: \(errmsg)")
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw PersistenceError.databaseError("Failed to prepare capability insert: \(errmsg)")
        }
        
        Logger.shared.info("Created capability: \(capability.name) in organization: \(capability.organization)")
    }
    
    public func listOrganizations() throws -> [DarwinOrganizationData] {
        var organizations: [DarwinOrganizationData] = []
        let query = "SELECT id, name, description, logo_url, is_installed, is_local_only, created_at, updated_at, metadata_json FROM organizations;"
        var statement: OpaquePointer?
        
        defer {
            if statement != nil {
                sqlite3_finalize(statement)
            }
        }
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                let description = sqlite3_column_text(statement, 2).map { String(cString: $0) }
                let logo = sqlite3_column_text(statement, 3).map { String(cString: $0) }
                
                // Parse metadata from JSON
                var types: [String] = []
                var tags: [String]? = nil
                var pngLogo: String? = nil
                var svgLogo: String? = nil
                
                if let metadataJsonString = sqlite3_column_text(statement, 8).map({ String(cString: $0) }),
                   let metadataData = metadataJsonString.data(using: .utf8),
                   let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any] {
                    types = metadata["types"] as? [String] ?? []
                    tags = metadata["tags"] as? [String]
                    pngLogo = metadata["pngLogo"] as? String
                    svgLogo = metadata["svgLogo"] as? String
                }
                
                organizations.append(DarwinOrganizationData(
                    id: id,
                    name: name,
                    description: description ?? "",
                    logo: logo,
                    pngLogo: pngLogo ?? logo,
                    svgLogo: svgLogo,
                    types: types,
                    children: nil,
                    tags: tags
                ))
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw PersistenceError.databaseError("Failed to list organizations: \(errmsg)")
        }
        
        return organizations
    }
    
    public func listCapabilities(for organizationId: String) throws -> [DarwinCapabilityMetadata] {
        var capabilities: [DarwinCapabilityMetadata] = []
        let query = "SELECT name, description, type, entry_point, inputs, outputs, auth_type FROM capabilities WHERE organization_id = ?;"
        var statement: OpaquePointer?
        
        defer {
            if statement != nil {
                sqlite3_finalize(statement)
            }
        }
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, organizationId, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(statement, 0))
                let description = String(cString: sqlite3_column_text(statement, 1))
                let type = String(cString: sqlite3_column_text(statement, 2))
                let entryPoint = String(cString: sqlite3_column_text(statement, 3))
                
                // Parse inputs and outputs from JSON
                let inputsString = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? "[]"
                let outputsString = sqlite3_column_text(statement, 5).map { String(cString: $0) } ?? "{}"
                let authTypeString = sqlite3_column_text(statement, 6).map { String(cString: $0) } ?? "none"
                
                let inputs = (try? jsonDecoder.decode([DarwinFunctionParameter].self, from: inputsString.data(using: .utf8) ?? Data())) ?? []
                let output = (try? jsonDecoder.decode(DarwinCapabilityOutput.self, from: outputsString.data(using: .utf8) ?? Data())) ?? DarwinCapabilityOutput(type: "string", description: "")
                let authType = DarwinAuthenticationType(rawValue: authTypeString) ?? .none
                
                capabilities.append(DarwinCapabilityMetadata(
                    type: type,
                    name: name,
                    description: description,
                    entry_point: entryPoint,
                    organization: organizationId,
                    inputs: inputs,
                    output: output,
                    base_url: nil,
                    auth_type: authType,
                    headers: nil,
                    auth: nil
                ))
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw PersistenceError.databaseError("Failed to list capabilities: \(errmsg)")
        }
        
        return capabilities
    }
    
    public func listInstalledCapabilities() throws -> [DarwinCapabilityMetadata] {
        var capabilities: [DarwinCapabilityMetadata] = []
        let query = """
            SELECT c.name, c.description, c.type, c.entry_point, c.inputs, c.outputs, c.auth_type, c.organization_id
            FROM capabilities c
            INNER JOIN installations i ON c.id = i.capability_id
            ORDER BY c.organization_id, c.name;
        """
        var statement: OpaquePointer?
        
        defer {
            if statement != nil {
                sqlite3_finalize(statement)
            }
        }
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(statement, 0))
                let description = String(cString: sqlite3_column_text(statement, 1))
                let type = String(cString: sqlite3_column_text(statement, 2))
                let entryPoint = String(cString: sqlite3_column_text(statement, 3))
                let organizationId = String(cString: sqlite3_column_text(statement, 7))
                
                // Parse inputs
                let inputs: [DarwinFunctionParameter] = []
                // Parse outputs - simplified for now
                let output = DarwinCapabilityOutput(type: "string", description: "Output")
                
                // Parse auth type
                let authTypeStr = sqlite3_column_text(statement, 6).map { String(cString: $0) } ?? "none"
                let authType = DarwinAuthenticationType(rawValue: authTypeStr) ?? .none
                
                capabilities.append(DarwinCapabilityMetadata(
                    type: type,
                    name: name,
                    description: description,
                    entry_point: entryPoint,
                    organization: organizationId,
                    inputs: inputs,
                    output: output,
                    base_url: nil,
                    auth_type: authType,
                    headers: nil,
                    auth: nil
                ))
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            throw PersistenceError.databaseError("Failed to list installed capabilities: \(errmsg)")
        }
        
        return capabilities
    }
    
    public func removeOrganization(organizationId: String) throws {
        // First remove all capabilities
        let deleteCapabilities = "DELETE FROM capabilities WHERE organization_id = ?;"
        var statement: OpaquePointer?
        
        defer {
            if statement != nil {
                sqlite3_finalize(statement)
            }
        }
        
        if sqlite3_prepare_v2(db, deleteCapabilities, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, organizationId, -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db))
                throw PersistenceError.databaseError("Failed to delete capabilities: \(errmsg)")
            }
        }
        
        // Then remove the organization
        let deleteOrg = "DELETE FROM organizations WHERE id = ?;"
        statement = nil
        
        if sqlite3_prepare_v2(db, deleteOrg, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, organizationId, -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db))
                throw PersistenceError.databaseError("Failed to delete organization: \(errmsg)")
            }
        }
        
        // Remove directory
        let orgDir = repositoryDirectory.appendingPathComponent(organizationId)
        try? FileManager.default.removeItem(at: orgDir)
        
        Logger.shared.info("Removed organization: \(organizationId)")
    }
    
    public func removeCapability(
        capabilityName: String,
        from organizationId: String
    ) throws {
        let deleteQuery = "DELETE FROM capabilities WHERE name = ? AND organization_id = ?;"
        var statement: OpaquePointer?
        
        defer {
            if statement != nil {
                sqlite3_finalize(statement)
            }
        }
        
        if sqlite3_prepare_v2(db, deleteQuery, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, capabilityName, -1, nil)
            sqlite3_bind_text(statement, 2, organizationId, -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db))
                throw PersistenceError.databaseError("Failed to delete capability: \(errmsg)")
            }
        }
        
        // Remove capability directory (try to find it)
        let orgDir = repositoryDirectory.appendingPathComponent(organizationId)
        if let enumerator = FileManager.default.enumerator(at: orgDir, includingPropertiesForKeys: nil) {
            for case let path as URL in enumerator {
                if path.lastPathComponent == capabilityName && path.hasDirectoryPath {
                    try? FileManager.default.removeItem(at: path)
                    break
                }
            }
        }
        
        Logger.shared.info("Removed capability: \(capabilityName) from organization: \(organizationId)")
    }
    
    public func organizationExists(organizationId: String) -> Bool {
        let query = "SELECT id FROM organizations WHERE id = ?;"
        var statement: OpaquePointer?
        
        defer {
            if statement != nil {
                sqlite3_finalize(statement)
            }
        }
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, organizationId, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                return true
            }
        }
        
        return false
    }
    
    public func capabilityExists(
        capabilityName: String,
        in organizationId: String
    ) -> Bool {
        let query = "SELECT name FROM capabilities WHERE name = ? AND organization_id = ?;"
        var statement: OpaquePointer?
        
        defer {
            if statement != nil {
                sqlite3_finalize(statement)
            }
        }
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, capabilityName, -1, nil)
            sqlite3_bind_text(statement, 2, organizationId, -1, nil)
            
            if sqlite3_step(statement) == SQLITE_ROW {
                return true
            }
        }
        
        return false
    }
    
    /// Create a group directory with org.json file
    public func createGroup(
        organizationId: String,
        groupId: String,
        groupData: DarwinOrganizationData
    ) throws {
        // Ensure organization exists
        guard organizationExists(organizationId: organizationId) else {
            throw PersistenceError.organizationNotFound(organizationId)
        }
        
        // Create group directory
        let groupDir = repositoryDirectory
            .appendingPathComponent(organizationId)
            .appendingPathComponent(groupId)
        try FileManager.default.createDirectory(at: groupDir, withIntermediateDirectories: true)
        
        // Create org.json file for the group with parent field
        let groupJsonPath = groupDir.appendingPathComponent("org.json")
        
        // Create a custom dictionary to include parent field
        var groupDict: [String: Any] = [
            "id": groupData.id,
            "name": groupData.name,
            "description": groupData.description,
            "types": groupData.types,
            "parent": organizationId
        ]
        
        if let logo = groupData.logo {
            groupDict["logo"] = logo
        }
        if let pngLogo = groupData.pngLogo {
            groupDict["pngLogo"] = pngLogo
        }
        if let svgLogo = groupData.svgLogo {
            groupDict["svgLogo"] = svgLogo
        }
        if let tags = groupData.tags {
            groupDict["tags"] = tags
        }
        
        let groupJsonData = try JSONSerialization.data(withJSONObject: groupDict, options: .prettyPrinted)
        try groupJsonData.write(to: groupJsonPath)
        
        Logger.shared.info("Created group: \(groupId) in organization: \(organizationId)")
    }
}
