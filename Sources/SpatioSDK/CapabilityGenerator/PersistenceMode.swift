import Foundation

/// Defines where organizations and capabilities should be persisted
public enum PersistenceMode {
    /// Local persistence to Darwin AI's local storage
    /// - Uses: ~/.darwin/store/installed.db and ~/.darwin/store/repository/
    /// - Purpose: For Darwin AI core tools and local development
    case local
    
    /// Remote persistence to capabilities-store repository
    /// - Uses: {capabilitiesStorePath}/src/ directory structure
    /// - Purpose: For contributing capabilities to the global store
    /// - Requires: Local capabilities-store repository clone
    case remote(capabilitiesStorePath: String)
    
    /// Darwin AI native persistence
    /// - Uses: ~/.darwin/store/installed.db with Darwin AI's exact schema
    /// - Purpose: For creating core tools and native Darwin AI capabilities
    /// - Compatible with Darwin AI's CapabilityStoreService
    case darwin
}

extension PersistenceMode {
    /// Validates the persistence mode configuration
    /// - Returns: Validation result with any errors
    public func validate() -> ValidationResult {
        switch self {
        case .local:
            return validateLocalMode()
        case .remote(let path):
            return validateRemoteMode(path: path)
        case .darwin:
            return validateDarwinMode()
        }
    }
    
    /// Validates local persistence mode
    private func validateLocalMode() -> ValidationResult {
        let darwinStoreDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".darwin")
            .appendingPathComponent("store")
        
        var errors: [String] = []
        var warnings: [String] = []
        
        // Check if .darwin/store directory exists or can be created
        if !FileManager.default.fileExists(atPath: darwinStoreDir.path) {
            do {
                try FileManager.default.createDirectory(
                    at: darwinStoreDir,
                    withIntermediateDirectories: true
                )
            } catch {
                errors.append("Cannot create Darwin AI store directory: \(error.localizedDescription)")
            }
        }
        
        // Check write permissions
        if !FileManager.default.isWritableFile(atPath: darwinStoreDir.path) {
            errors.append("No write permission to Darwin AI store directory: \(darwinStoreDir.path)")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    /// Validates remote persistence mode
    private func validateRemoteMode(path: String) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Check if path is provided
        if path.isEmpty {
            errors.append("Remote persistence requires explicit capabilities-store path")
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
        
        let capabilitiesStorePath = URL(fileURLWithPath: path)
        
        // Check if path exists
        if !FileManager.default.fileExists(atPath: capabilitiesStorePath.path) {
            errors.append("Capabilities-store path does not exist: \(path)")
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
        
        // Check if it's a directory
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: capabilitiesStorePath.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            errors.append("Capabilities-store path is not a directory: \(path)")
            return ValidationResult(isValid: false, errors: errors, warnings: warnings)
        }
        
        // Check if it's a valid capabilities-store repository
        let srcDir = capabilitiesStorePath.appendingPathComponent("src")
        let packageJson = capabilitiesStorePath.appendingPathComponent("package.json")
        let schemaDir = capabilitiesStorePath.appendingPathComponent("schema")
        
        if !FileManager.default.fileExists(atPath: srcDir.path) {
            errors.append("Path is not a valid capabilities-store repository (missing src/ directory): \(path)")
        }
        
        if !FileManager.default.fileExists(atPath: packageJson.path) {
            warnings.append("Path may not be a capabilities-store repository (missing package.json): \(path)")
        }
        
        if !FileManager.default.fileExists(atPath: schemaDir.path) {
            warnings.append("Path may not be a capabilities-store repository (missing schema/ directory): \(path)")
        }
        
        // Check write permissions to src directory
        if FileManager.default.fileExists(atPath: srcDir.path) {
            if !FileManager.default.isWritableFile(atPath: srcDir.path) {
                errors.append("No write permission to capabilities-store src directory: \(srcDir.path)")
            }
        }
        
        // Check if it's a git repository
        let gitDir = capabilitiesStorePath.appendingPathComponent(".git")
        if !FileManager.default.fileExists(atPath: gitDir.path) {
            warnings.append("Capabilities-store path is not a git repository. You'll need to manually commit and push changes.")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    /// Validates Darwin AI native persistence mode
    private func validateDarwinMode() -> ValidationResult {
        let darwinStoreDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".darwin")
            .appendingPathComponent("store")
        
        var errors: [String] = []
        var warnings: [String] = []
        
        // Check if .darwin/store directory exists
        if !FileManager.default.fileExists(atPath: darwinStoreDir.path) {
            do {
                try FileManager.default.createDirectory(
                    at: darwinStoreDir,
                    withIntermediateDirectories: true
                )
            } catch {
                errors.append("Cannot create Darwin AI store directory: \(error.localizedDescription)")
            }
        }
        
        // Check write permissions
        if !FileManager.default.isWritableFile(atPath: darwinStoreDir.path) {
            errors.append("No write permission to Darwin AI store directory: \(darwinStoreDir.path)")
        }
        
        // Check if installed.db exists or can be created
        let dbPath = darwinStoreDir.appendingPathComponent("installed.db")
        if !FileManager.default.fileExists(atPath: dbPath.path) {
            warnings.append("Darwin AI database does not exist yet at: \(dbPath.path)")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
}

extension PersistenceMode: CustomStringConvertible {
    public var description: String {
        switch self {
        case .local:
            return "Local (~/.darwin/store/)"
        case .remote(let path):
            return "Remote (\(path))"
        case .darwin:
            return "Darwin AI Native (~/.darwin/store/installed.db)"
        }
    }
}

extension PersistenceMode: Equatable {
    public static func == (lhs: PersistenceMode, rhs: PersistenceMode) -> Bool {
        switch (lhs, rhs) {
        case (.local, .local):
            return true
        case (.remote(let path1), .remote(let path2)):
            return path1 == path2
        case (.darwin, .darwin):
            return true
        default:
            return false
        }
    }
}