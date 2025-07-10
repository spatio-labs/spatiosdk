import Foundation

/// Represents an installed capability with UI-ready properties
public struct InstalledCapability: Codable, Identifiable {
    public let id: String
    public let name: String
    public let organization: String
    public let description: String
    public let type: String
    public let version: String?
    public let installedAt: Date
    public let lastUsedAt: Date?
    public let usageCount: Int
    public let isEnabled: Bool
    
    /// Initialize an InstalledCapability
    public init(
        id: String,
        name: String,
        organization: String,
        description: String,
        type: String,
        version: String? = nil,
        installedAt: Date,
        lastUsedAt: Date? = nil,
        usageCount: Int = 0,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.organization = organization
        self.description = description
        self.type = type
        self.version = version
        self.installedAt = installedAt
        self.lastUsedAt = lastUsedAt
        self.usageCount = usageCount
        self.isEnabled = isEnabled
    }
}

// MARK: - Conversion Extensions

extension DarwinCapabilityMetadata {
    /// Convert DarwinCapabilityMetadata to InstalledCapability
    public func toInstalledCapability(
        installedAt: Date = Date(),
        lastUsedAt: Date? = nil,
        usageCount: Int = 0,
        isEnabled: Bool = true
    ) -> InstalledCapability {
        return InstalledCapability(
            id: UUID().uuidString,
            name: self.name,
            organization: self.organization,
            description: self.description,
            type: self.type,
            version: nil, // TODO: Add version support to DarwinCapabilityMetadata
            installedAt: installedAt,
            lastUsedAt: lastUsedAt,
            usageCount: usageCount,
            isEnabled: isEnabled
        )
    }
}

extension InstalledCapability {
    /// Convert InstalledCapability back to DarwinCapabilityMetadata
    /// Note: This requires additional metadata that's not stored in InstalledCapability
    /// This is mainly for compatibility - prefer using the persistence layer directly
    public func toDarwinCapabilityMetadata(
        inputs: [DarwinFunctionParameter] = [],
        output: DarwinCapabilityOutput = DarwinCapabilityOutput(type: "string", description: "Output"),
        group: String = "default",
        entry_point: String = "main",
        base_url: String? = nil,
        auth_type: DarwinAuthenticationType = .none,
        headers: [DarwinCapabilityHeader]? = nil,
        auth: DarwinCapabilityAuthInfo? = nil
    ) -> DarwinCapabilityMetadata {
        return DarwinCapabilityMetadata(
            type: self.type,
            name: self.name,
            description: self.description,
            entry_point: entry_point,
            organization: self.organization,
            group: group,
            inputs: inputs,
            output: output,
            base_url: base_url,
            auth_type: auth_type,
            headers: headers,
            auth: auth
        )
    }
}

// MARK: - UI Helper Extensions

extension InstalledCapability {
    /// Get a color for the capability type
    public var typeColor: String {
        switch type.lowercased() {
        case "function", "local":
            return "green"
        case "api", "apirequest", "remote":
            return "orange"
        case "builtin", "system":
            return "blue"
        default:
            return "gray"
        }
    }
    
    /// Get an icon for the capability type
    public var typeIcon: String {
        switch type.lowercased() {
        case "function", "local":
            return "function"
        case "api", "apirequest", "remote":
            return "network"
        case "builtin", "system":
            return "gear"
        default:
            return "app"
        }
    }
    
    /// Get a formatted installation date
    public var formattedInstallDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: installedAt)
    }
    
    /// Get a formatted last used date
    public var formattedLastUsedDate: String? {
        guard let lastUsedAt = lastUsedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastUsedAt)
    }
}

// MARK: - Grouping Helpers

extension Array where Element == InstalledCapability {
    /// Group capabilities by organization
    public var groupedByOrganization: [String: [InstalledCapability]] {
        return Dictionary(grouping: self) { $0.organization }
    }
    
    /// Group capabilities by type
    public var groupedByType: [String: [InstalledCapability]] {
        return Dictionary(grouping: self) { $0.type }
    }
    
    /// Filter capabilities by search text
    public func filtered(by searchText: String) -> [InstalledCapability] {
        guard !searchText.isEmpty else { return self }
        return self.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.organization.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    /// Filter capabilities by enabled status
    public var enabledOnly: [InstalledCapability] {
        return self.filter { $0.isEnabled }
    }
    
    /// Sort capabilities by name
    public var sortedByName: [InstalledCapability] {
        return self.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    /// Sort capabilities by install date (newest first)
    public var sortedByInstallDate: [InstalledCapability] {
        return self.sorted { $0.installedAt > $1.installedAt }
    }
    
    /// Sort capabilities by usage count (most used first)
    public var sortedByUsage: [InstalledCapability] {
        return self.sorted { $0.usageCount > $1.usageCount }
    }
}