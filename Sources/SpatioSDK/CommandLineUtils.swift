import Foundation

/// Command-line utilities for capability scripts
public enum CommandLineUtils {
    /// Parse command-line arguments based on API parameters
    /// - Parameter apiParams: List of API parameters that define expected arguments
    /// - Returns: Dictionary of parameter names to values
    public static func parseArguments(for apiParams: [APIParameter]) -> [String: String] {
        var result = [String: String]()
        
        // Skip program name (first argument)
        let args = Array(CommandLine.arguments.dropFirst())
        
        // Get required parameters (in order)
        let requiredParams = apiParams.filter { $0.required }
        let optionalParams = apiParams.filter { !$0.required }
        
        // First, assign positional arguments to required parameters
        for (index, param) in requiredParams.enumerated() {
            if index < args.count {
                result[param.name] = args[index]
            } else if let defaultValue = param.defaultValue {
                result[param.name] = defaultValue
            } else {
                print("Error: Missing required parameter '\(param.name)'")
                exit(1)
            }
        }
        
        // Process any remaining arguments that look like named parameters
        for arg in args.dropFirst(requiredParams.count) {
            if arg.starts(with: "--") || arg.starts(with: "-") {
                let argTrimmed = arg.hasPrefix("--") ? String(arg.dropFirst(2)) : String(arg.dropFirst(1))
                
                if argTrimmed.contains("=") {
                    let components = argTrimmed.split(separator: "=", maxSplits: 1)
                    if components.count == 2 {
                        let paramName = String(components[0])
                        let paramValue = String(components[1])
                        result[paramName] = paramValue
                    }
                }
            }
        }
        
        // Add default values for optional parameters that weren't provided
        for param in optionalParams {
            if result[param.name] == nil, let defaultValue = param.defaultValue {
                result[param.name] = defaultValue
            }
        }
        
        return result
    }
    
    /// Print the capability result as JSON to stdout
    /// - Parameter result: The capability result to print
    public static func printResult(_ result: CapabilityResult) {
        do {
            let jsonData = try result.toJSON()
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            } else {
                print(result.output)
            }
        } catch {
            print(result.output)
        }
    }
} 