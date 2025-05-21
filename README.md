# SpatioSDK

A Swift package for building capabilities for Spatio, with support for local and remote API integrations.

## Overview

SpatioSDK provides the core models and utilities needed for creating capabilities that interact with remote APIs:

- API parameter models and request handling
- Flexible authentication configuration
- Command line argument parsing
- Capability result formatting
- Mock data support for testing

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SpatioSDK.git", .upToNextMajor(from: "1.0.0"))
]
```

### For Capability Scripts with swift-sh

```swift
#!/usr/bin/env swift sh
import SpatioSDK // @YourGitHubUsername ~> 1.0.0
```

## Authentication System

SpatioSDK provides a flexible authentication system that supports:

- Multiple authentication types (API key, OAuth2, Basic, etc.)
- Configuration at organization, group, or capability level
- Environment variable-based secret storage

### Configuration Levels

Authentication can be configured at three levels:

1. **Organization level** - Applies to all capabilities in an organization
2. **Group level** - Applies to all capabilities in a group
3. **Capability level** - Applies to a specific capability

More specific configurations override less specific ones.

### Example: Configuring Auth

```swift
// Configure OAuth2 for all Google services
let googleOAuth = AuthConfig(
    type: .oauth2,
    parameterName: "Authorization",
    location: .header,
    valuePrefix: "Bearer ",
    envVariable: "GOOGLE_AUTH_TOKEN"
)

// Set at organization level
AuthManager.shared.setAuthConfig(for: "google", config: googleOAuth)

// Override for a specific group if needed
let apiKeyConfig = AuthConfig(
    type: .apiKey,
    parameterName: "api_key",
    location: .query,
    envVariable: "MY_SERVICE_API_KEY"
)
AuthManager.shared.setAuthConfig(for: "google", group: "maps", config: apiKeyConfig)
```

## Building Capabilities

### Creating a Remote API Capability

1. Create a Swift script using swift-sh that imports SpatioSDK:

```swift
#!/usr/bin/env swift sh
import SpatioSDK // @YourGitHubUsername ~> 1.0.0
import Foundation

// Configure authentication
func configureAuth() {
    let authConfig = AuthConfig(
        type: .apiKey,
        parameterName: "Authorization",
        location: .header,
        valuePrefix: "Bearer ",
        envVariable: "API_AUTH_TOKEN"
    )
    AuthManager.shared.setAuthConfig(for: "myorg", config: authConfig)
}

// Implement the capability
class MyApiCapability: BaseRemoteCapability {
    override func configureRequest() -> APIRequest {
        return APIRequest(
            baseURL: "https://api.example.com",
            endpoint: "/resource",
            method: "GET",
            parameters: [
                APIParameter(
                    name: "query",
                    type: "string",
                    required: true,
                    location: .query,
                    description: "Search query"
                )
            ]
        )
    }

    // No mock data implementation for production capabilities
}

// Parse command line arguments
@main
struct MyCapabilityScript {
    static func main() async throws {
        // Configure auth
        configureAuth()
        
        // Create capability with identifiers
        let capability = MyApiCapability(
            organization: "myorg",
            group: "mygroup",
            capability: "MyCapability"
        )
        
        // Parse command line arguments
        let params = CommandLineUtils.parseArguments(for: capability.request.parameters)
        
        // Execute the capability
        let result = try await capability.execute(params: params)
        CommandLineUtils.printResult(result)
    }
}
```

2. Make the script executable:

```bash
chmod +x my_capability.swift
```

3. Compile the script into a binary:

```bash
swift sh my_capability.swift --compile -o my_capability
```

## Testing

Run the script directly during development:

```bash
export API_AUTH_TOKEN=your_token_here
./my_capability.swift "search term"
```

Use the compiled binary in production:

```bash
export API_AUTH_TOKEN=your_token_here
./my_capability "search term"
``` 