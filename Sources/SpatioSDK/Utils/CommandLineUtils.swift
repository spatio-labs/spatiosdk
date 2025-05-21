import Foundation

/// Utilities for command-line capabilities
public class CommandLineUtils {
    /// Parse command line arguments into a parameter dictionary
    /// - Parameter parameters: The API parameters to expect
    /// - Returns: Dictionary with parameter values
    public static func parseArguments(for parameters: [APIParameter]) -> [String: String] {
        let args = Array(CommandLine.arguments.dropFirst())
        var result: [String: String] = [:]
        
        // Process named parameters (--param value)
        var i = 0
        while i < args.count {
            let arg = args[i]
            
            if arg.hasPrefix("--") {
                let paramName = String(arg.dropFirst(2))
                
                if i + 1 < args.count && !args[i + 1].hasPrefix("--") {
                    result[paramName] = args[i + 1]
                    i += 2
                } else {
                    // Boolean flag
                    result[paramName] = "true"
                    i += 1
                }
            } else {
                // Positional parameters (based on parameter order)
                let positionalIndex = i
                if positionalIndex < parameters.count {
                    result[parameters[positionalIndex].name] = arg
                }
                i += 1
            }
        }
        
        // Add default values for parameters not provided
        for param in parameters {
            if result[param.name] == nil, let defaultValue = param.defaultValue {
                result[param.name] = defaultValue
            }
        }
        
        return result
    }
    
    /// Print JSON result to stdout
    /// - Parameter json: JSON string to print
    public static func printResult(_ json: String) {
        print(json)
    }
} 