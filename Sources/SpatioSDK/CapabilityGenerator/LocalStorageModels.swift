import Foundation
import SQLite

// MARK: - Local Storage Models for Darwin AI installed.db

/// Models representing the Darwin AI local storage schema
/// Based on CapabilityStorageManager.swift from Darwin AI

// MARK: - Organization Models

/// Local organization data structure for installed.db
public struct LocalOrganizationData: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let logoUrl: String?
    public let isInstalled: Bool
    public let isLocalOnly: Bool
    public let createdAt: Int64
    public let updatedAt: Int64
    public let metadataJson: String?
    public let tags: String?
    
    public init(
        id: String,
        name: String,
        description: String? = nil,
        logoUrl: String? = nil,
        isInstalled: Bool = false,
        isLocalOnly: Bool = false,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970),
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970),
        metadataJson: String? = nil,
        tags: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.logoUrl = logoUrl
        self.isInstalled = isInstalled
        self.isLocalOnly = isLocalOnly
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadataJson = metadataJson
        self.tags = tags
    }
}

// MARK: - Group Models

/// Local group data structure for installed.db
public struct LocalGroupData: Codable, Identifiable {
    public let id: String
    public let organizationId: String
    public let name: String
    public let description: String?
    public let logoUrl: String?
    public let createdAt: Int64
    public let updatedAt: Int64
    public let metadataJson: String?
    
    public init(
        id: String,
        organizationId: String,
        name: String,
        description: String? = nil,
        logoUrl: String? = nil,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970),
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970),
        metadataJson: String? = nil
    ) {
        self.id = id
        self.organizationId = organizationId
        self.name = name
        self.description = description
        self.logoUrl = logoUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadataJson = metadataJson
    }
}

// MARK: - Capability Models

/// Local capability data structure for installed.db
public struct LocalCapabilityData: Codable, Identifiable {
    public let id: String
    public let name: String
    public let organizationId: String
    public let groupId: String?
    public let description: String?
    public let type: String
    public let entryPoint: String?
    public let filePath: String
    public let logoUrl: String?
    public let isInstalled: Bool
    public let isEnabled: Bool
    public let version: String?
    public let createdAt: Int64
    public let updatedAt: Int64
    public let lastExecutedAt: Int64?
    public let executionCount: Int64
    public let tags: String?
    public let metadataJson: String?
    
    public init(
        id: String,
        name: String,
        organizationId: String,
        groupId: String? = nil,
        description: String? = nil,
        type: String,
        entryPoint: String? = nil,
        filePath: String,
        logoUrl: String? = nil,
        isInstalled: Bool = false,
        isEnabled: Bool = true,
        version: String? = nil,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970),
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970),
        lastExecutedAt: Int64? = nil,
        executionCount: Int64 = 0,
        tags: String? = nil,
        metadataJson: String? = nil
    ) {
        self.id = id
        self.name = name
        self.organizationId = organizationId
        self.groupId = groupId
        self.description = description
        self.type = type
        self.entryPoint = entryPoint
        self.filePath = filePath
        self.logoUrl = logoUrl
        self.isInstalled = isInstalled
        self.isEnabled = isEnabled
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastExecutedAt = lastExecutedAt
        self.executionCount = executionCount
        self.tags = tags
        self.metadataJson = metadataJson
    }
}

// MARK: - Parameter Models

/// Local capability parameter data structure for installed.db
public struct LocalCapabilityParameter: Codable, Identifiable {
    public let id: Int64?
    public let capabilityId: String
    public let name: String
    public let type: String
    public let required: Bool
    public let description: String?
    public let defaultValue: String?
    
    public init(
        id: Int64? = nil,
        capabilityId: String,
        name: String,
        type: String,
        required: Bool,
        description: String? = nil,
        defaultValue: String? = nil
    ) {
        self.id = id
        self.capabilityId = capabilityId
        self.name = name
        self.type = type
        self.required = required
        self.description = description
        self.defaultValue = defaultValue
    }
}

// MARK: - Installation Models

/// Local installation tracking data structure for installed.db
public struct LocalInstallationData: Codable {
    public let capabilityId: String
    public let installedAt: Int64
    public let source: String?
    public let metadata: String?
    
    public init(
        capabilityId: String,
        installedAt: Int64 = Int64(Date().timeIntervalSince1970),
        source: String? = nil,
        metadata: String? = nil
    ) {
        self.capabilityId = capabilityId
        self.installedAt = installedAt
        self.source = source
        self.metadata = metadata
    }
}

// MARK: - Usage Models

/// Local usage tracking data structure for installed.db
public struct LocalUsageData: Codable, Identifiable {
    public let id: Int64?
    public let capabilityId: String
    public let executedAt: Int64
    public let executionTimeMs: Int64?
    public let success: Bool?
    public let errorMessage: String?
    public let parametersJson: String?
    
    public init(
        id: Int64? = nil,
        capabilityId: String,
        executedAt: Int64 = Int64(Date().timeIntervalSince1970),
        executionTimeMs: Int64? = nil,
        success: Bool? = nil,
        errorMessage: String? = nil,
        parametersJson: String? = nil
    ) {
        self.id = id
        self.capabilityId = capabilityId
        self.executedAt = executedAt
        self.executionTimeMs = executionTimeMs
        self.success = success
        self.errorMessage = errorMessage
        self.parametersJson = parametersJson
    }
}

// MARK: - Conversion Extensions

extension LocalOrganizationData {
    /// Convert to Darwin AI organization format
    func toDarwinOrganizationData() -> DarwinOrganizationData {
        return DarwinOrganizationData(
            id: id,
            name: name,
            description: description ?? "",
            logo: logoUrl,
            types: isLocalOnly ? ["local"] : ["local", "remote"],
            tags: tags?.components(separatedBy: ",")
        )
    }
}

extension DarwinOrganizationData {
    /// Convert to local organization format
    func toLocalOrganizationData(isInstalled: Bool = true, isLocalOnly: Bool = false) -> LocalOrganizationData {
        return LocalOrganizationData(
            id: id,
            name: name,
            description: description,
            logoUrl: logo ?? pngLogo ?? svgLogo,
            isInstalled: isInstalled,
            isLocalOnly: isLocalOnly,
            metadataJson: try? String(data: JSONEncoder().encode(self), encoding: .utf8),
            tags: tags?.joined(separator: ",")
        )
    }
}

extension LocalCapabilityData {
    /// Convert to Darwin AI capability format
    func toDarwinCapabilityMetadata() -> DarwinCapabilityMetadata {
        let inputs = parseParameters()
        let output = DarwinCapabilityOutput(type: "string", description: "Capability output")
        
        return DarwinCapabilityMetadata(
            type: type,
            name: name,
            description: description ?? "",
            entry_point: entryPoint ?? "",
            organization: organizationId,
            group: groupId ?? organizationId,
            inputs: inputs,
            output: output,
            auth_type: .none
        )
    }
    
    /// Parse parameters from metadata JSON
    private func parseParameters() -> [DarwinFunctionParameter] {
        // This would parse the metadataJson to extract parameters
        // For now, return empty array
        return []
    }
}

extension DarwinCapabilityMetadata {
    /// Convert to local capability format
    func toLocalCapabilityData(
        filePath: String,
        isInstalled: Bool = true,
        isEnabled: Bool = true
    ) -> LocalCapabilityData {
        return LocalCapabilityData(
            id: UUID().uuidString,
            name: name,
            organizationId: organization,
            groupId: group != organization ? group : nil,
            description: description,
            type: type,
            entryPoint: entry_point,
            filePath: filePath,
            isInstalled: isInstalled,
            isEnabled: isEnabled,
            metadataJson: try? String(data: JSONEncoder().encode(self), encoding: .utf8)
        )
    }
}

// MARK: - Helper Extensions

extension String {
    var tags: [String] {
        return components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

extension Array where Element == String {
    var tagsString: String {
        return joined(separator: ",")
    }
}