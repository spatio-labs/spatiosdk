import Foundation

// MARK: - Store-specific Models for App Store Browsing

/// Represents an organization in the app store
public struct StoreOrganization: Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let logoUrl: String?
    public let pngLogoUrl: String?
    public let svgLogoUrl: String?
    public let children: [String]
    public let capabilityCount: Int
    public let tags: [String]?
    
    public init(
        id: String,
        name: String,
        description: String,
        logoUrl: String? = nil,
        pngLogoUrl: String? = nil,
        svgLogoUrl: String? = nil,
        children: [String] = [],
        capabilityCount: Int = 0,
        tags: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.logoUrl = logoUrl
        self.pngLogoUrl = pngLogoUrl
        self.svgLogoUrl = svgLogoUrl
        self.children = children
        self.capabilityCount = capabilityCount
        self.tags = tags
    }
    
    /// Get the preferred logo URL (PNG preferred for Mac)
    public var preferredLogoUrl: String? {
        return pngLogoUrl ?? logoUrl ?? svgLogoUrl
    }
}

/// Represents a featured organization in the store
public struct FeaturedOrganization: Identifiable, Codable {
    public let id: String
    public let organization: StoreOrganization
    public let priority: Int
    public let displayOrder: Int
    
    public init(
        id: String,
        organization: StoreOrganization,
        priority: Int = 0,
        displayOrder: Int = 0
    ) {
        self.id = id
        self.organization = organization
        self.priority = priority
        self.displayOrder = displayOrder
    }
}

/// Represents a capability in the app store
public struct StoreCapability: Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let organizationId: String
    public let groupId: String?
    public let version: String
    public let iconUrl: String?
    public let entryPoint: String
    public let type: String
    public let tags: [String]?
    public let isInstalled: Bool
    public let installedVersion: String?
    
    public init(
        id: String,
        name: String,
        description: String,
        organizationId: String,
        groupId: String? = nil,
        version: String = "1.0.0",
        iconUrl: String? = nil,
        entryPoint: String = "main",
        type: String = "function",
        tags: [String]? = nil,
        isInstalled: Bool = false,
        installedVersion: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.organizationId = organizationId
        self.groupId = groupId
        self.version = version
        self.iconUrl = iconUrl
        self.entryPoint = entryPoint
        self.type = type
        self.tags = tags
        self.isInstalled = isInstalled
        self.installedVersion = installedVersion
    }
    
    /// Check if an update is available
    public var hasUpdate: Bool {
        guard isInstalled, let installedVersion = installedVersion else { return false }
        return version != installedVersion
    }
}

/// Represents detailed information about an organization
public struct StoreOrganizationDetail: Codable {
    public let organization: StoreOrganization
    public let capabilities: [StoreCapability]
    public let subOrganizations: [StoreOrganization]
    public let parentOrganization: StoreOrganization?
    
    public init(
        organization: StoreOrganization,
        capabilities: [StoreCapability] = [],
        subOrganizations: [StoreOrganization] = [],
        parentOrganization: StoreOrganization? = nil
    ) {
        self.organization = organization
        self.capabilities = capabilities
        self.subOrganizations = subOrganizations
        self.parentOrganization = parentOrganization
    }
}

/// Installation status for store items
public enum StoreInstallationStatus {
    case notInstalled
    case downloading(progress: Double)
    case installing
    case installed
    case failed(error: String)
    case updateAvailable(currentVersion: String, newVersion: String)
}

/// Paginated response wrapper for store queries
public struct StorePaginatedResponse<T: Codable>: Codable {
    public let items: [T]
    public let page: Int
    public let pageSize: Int
    public let totalCount: Int
    public let totalPages: Int
    public let hasNextPage: Bool
    public let hasPreviousPage: Bool
    
    public init(
        items: [T],
        page: Int,
        pageSize: Int,
        totalCount: Int
    ) {
        self.items = items
        self.page = page
        self.pageSize = pageSize
        self.totalCount = totalCount
        self.totalPages = max(1, (totalCount + pageSize - 1) / pageSize)
        self.hasNextPage = page < self.totalPages
        self.hasPreviousPage = page > 1
    }
}

/// Search filters for store queries
public struct StoreSearchFilters {
    public let query: String?
    public let tags: [String]?
    public let organizationId: String?
    public let onlyInstalled: Bool
    public let onlyUpdatable: Bool
    
    public init(
        query: String? = nil,
        tags: [String]? = nil,
        organizationId: String? = nil,
        onlyInstalled: Bool = false,
        onlyUpdatable: Bool = false
    ) {
        self.query = query
        self.tags = tags
        self.organizationId = organizationId
        self.onlyInstalled = onlyInstalled
        self.onlyUpdatable = onlyUpdatable
    }
}