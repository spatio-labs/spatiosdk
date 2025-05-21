import Foundation

/// A sample capability implementation for demonstration purposes
public class SampleCapability: BaseRemoteCapability {
    /// Creates a new sample capability
    /// - Parameters:
    ///   - organization: The organization identifier
    ///   - group: The group identifier
    ///   - capability: The capability identifier
    public override init(organization: String = "sample", group: String = "demo", capability: String = "SampleCapability") {
        super.init(organization: organization, group: group, capability: capability)
    }
    
    /// Configure the API request for this capability
    public override func configureRequest() -> APIRequest {
        return APIRequest(
            baseURL: "https://api.example.com",
            endpoint: "/search",
            method: "GET",
            parameters: [
                APIParameter(
                    name: "query",
                    type: "string",
                    required: true,
                    location: .query,
                    description: "Search query"
                ),
                APIParameter(
                    name: "limit",
                    type: "integer",
                    required: false,
                    location: .query,
                    defaultValue: "10",
                    description: "Maximum number of results to return"
                ),
                APIParameter(
                    name: "format",
                    type: "string",
                    required: false,
                    location: .query,
                    defaultValue: "json",
                    description: "Response format (json or xml)"
                )
            ]
        )
    }
    
    /// Provide mock data for testing
    public override func provideMockData(for params: [String: String]) -> String {
        // Use a specific mock data file if it exists
        return MockHandler.shared.loadMockData(from: "sample_response", bundle: ResourceUtils.moduleBundle())
    }
}

/// Example of how to run the sample capability
/// ```swift
/// let capability = SampleCapability()
/// let result = try await capability.execute(params: ["query": "search term"])
/// print(result)
/// ``` 