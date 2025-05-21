import Foundation

/// Utilities for working with resources in capabilities
public class ResourceUtils {
    /// Load a resource file from the bundle
    /// - Parameters:
    ///   - name: The name of the resource
    ///   - extension: The file extension
    ///   - bundle: The bundle containing the resource
    /// - Returns: The contents of the resource file as a string
    public static func loadResource(
        named name: String,
        withExtension extension: String,
        bundle: Bundle = .main
    ) throws -> String {
        guard let url = bundle.url(forResource: name, withExtension: `extension`) else {
            throw NSError(domain: "ResourceUtils", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Resource not found: \(name).\(`extension`)"
            ])
        }
        
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    /// Load a JSON resource file and decode it to the specified type
    /// - Parameters:
    ///   - name: The name of the resource
    ///   - type: The type to decode to
    ///   - bundle: The bundle containing the resource
    /// - Returns: The decoded object
    public static func loadJSONResource<T: Decodable>(
        named name: String,
        as type: T.Type,
        bundle: Bundle = .main
    ) throws -> T {
        let jsonString = try loadResource(named: name, withExtension: "json", bundle: bundle)
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw NSError(domain: "ResourceUtils", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Failed to convert JSON string to data"
            ])
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: jsonData)
    }
    
    /// Get the bundle for the current module
    /// - Returns: The bundle for the SpatioSDK module
    public static func moduleBundle() -> Bundle {
        let bundleID = "com.spatio.SpatioSDK"
        
        // Try to find the bundle by identifier
        if let bundle = Bundle(identifier: bundleID) {
            return bundle
        }
        
        // For structs, we can't use Bundle(for:) directly
        // Instead, use the main bundle or the bundle containing this file
        let currentBundle = Bundle.main
        
        // For frameworks, we need to look for a bundle within the main bundle
        if let resourceBundleURL = currentBundle.url(forResource: "SpatioSDK", withExtension: "bundle"),
           let resourceBundle = Bundle(url: resourceBundleURL) {
            return resourceBundle
        }
        
        return currentBundle
    }
} 