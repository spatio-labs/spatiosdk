import Testing
import Foundation
@testable import SpatioSDK

@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}

@Suite("SpatioSDK Core Tests")
struct SpatioSDKTests {
    @Test func sdkVersionCheck() async throws {
        // Version should be set to 1.0.0 for the first release
        #expect(SpatioSDK.version == "1.0.0")
    }
    
    @Test func defaultConfigurationCheck() async throws {
        // Reset to ensure default state
        SpatioSDK.shared.reset()
        
        let config = SpatioSDK.shared.configuration()
        
        // Default logging level should be info
        #expect(config.loggingLevel == .info)
        
        // Mock data should be disabled by default
        #expect(config.useMockData == false)
    }
    
    @Test func configurationUpdates() async throws {
        // Create a new configuration
        let testConfig = SpatioConfig(
            loggingLevel: .debug,
            useMockData: true,
            baseURL: URL(string: "https://api.test.com")
        )
        
        // Apply the configuration
        SpatioSDK.shared.configure(with: testConfig)
        
        // Verify configuration is updated
        let config = SpatioSDK.shared.configuration()
        #expect(config.loggingLevel == .debug)
        #expect(config.useMockData == true)
        #expect(config.baseURL?.absoluteString == "https://api.test.com")
        
        // Reset configuration for other tests
        SpatioSDK.shared.reset()
        
        // Verify reset worked
        let resetConfig = SpatioSDK.shared.configuration()
        #expect(resetConfig.loggingLevel == .info)
        #expect(resetConfig.useMockData == false)
    }
}

@Suite("Authentication Tests")
struct AuthenticationTests {
    @Test func basicAuthConfiguration() async throws {
        // Set up a basic auth config
        let basicAuth = AuthConfig(
            type: .basic,
            parameterName: "Authorization",
            location: .header,
            valuePrefix: "Basic ",
            envVariable: "TEST_AUTH_TOKEN"
        )
        
        // Set at organization level
        AuthManager.shared.setAuthConfig(for: "testorg", config: basicAuth)
        
        // Verify config is retrievable
        let retrievedConfig = AuthManager.shared.getAuthConfig(for: "testorg", group: "testgroup", capability: "testcap")
        #expect(retrievedConfig != nil)
        #expect(retrievedConfig?.type == .basic)
        #expect(retrievedConfig?.parameterName == "Authorization")
        #expect(retrievedConfig?.location == .header)
        #expect(retrievedConfig?.valuePrefix == "Basic ")
        #expect(retrievedConfig?.envVariable == "TEST_AUTH_TOKEN")
    }
    
    @Test func authConfigurationOverrides() async throws {
        // Set up auth configs at different levels
        let orgAuth = AuthConfig(
            type: .apiKey,
            parameterName: "x-api-key",
            location: .header,
            envVariable: "ORG_API_KEY"
        )
        
        let groupAuth = AuthConfig(
            type: .oauth2,
            parameterName: "Authorization",
            location: .header,
            valuePrefix: "Bearer ",
            envVariable: "GROUP_OAUTH_TOKEN"
        )
        
        let capabilityAuth = AuthConfig(
            type: .basic,
            parameterName: "Authorization",
            location: .header,
            valuePrefix: "Basic ",
            envVariable: "CAPABILITY_BASIC_AUTH"
        )
        
        // Set configs at different levels
        AuthManager.shared.setAuthConfig(for: "override-org", config: orgAuth)
        AuthManager.shared.setAuthConfig(for: "override-org", group: "override-group", config: groupAuth)
        AuthManager.shared.setAuthConfig(for: "override-org", group: "override-group", capability: "override-cap", config: capabilityAuth)
        
        // Test that the most specific config is returned
        let capConfig = AuthManager.shared.getAuthConfig(for: "override-org", group: "override-group", capability: "override-cap")
        #expect(capConfig?.type == .basic)
        
        // Test that group config is returned when no capability config exists
        let groupConfig = AuthManager.shared.getAuthConfig(for: "override-org", group: "override-group", capability: "other-cap")
        #expect(groupConfig?.type == .oauth2)
        
        // Test that org config is returned when no group or capability config exists
        let orgConfig = AuthManager.shared.getAuthConfig(for: "override-org", group: "other-group", capability: "other-cap")
        #expect(orgConfig?.type == .apiKey)
    }
}

@Suite("API Request Tests")
struct APIRequestTests {
    @Test func apiParameterCreation() async throws {
        let param = APIParameter(
            name: "test_param",
            type: "string",
            required: true,
            location: .query,
            defaultValue: "default_value",
            description: "A test parameter"
        )
        
        #expect(param.name == "test_param")
        #expect(param.type == "string")
        #expect(param.required == true)
        #expect(param.location == .query)
        #expect(param.defaultValue == "default_value")
        #expect(param.description == "A test parameter")
    }
    
    @Test func apiRequestCreation() async throws {
        let request = APIRequest(
            baseURL: "https://api.example.com",
            endpoint: "/test",
            method: "POST",
            parameters: [
                APIParameter(name: "q", type: "string", required: true, location: .query),
                APIParameter(name: "token", type: "string", required: true, location: .header)
            ]
        )
        
        #expect(request.baseURL == "https://api.example.com")
        #expect(request.endpoint == "/test")
        #expect(request.method == "POST")
        #expect(request.parameters.count == 2)
        #expect(request.parameters[0].name == "q")
        #expect(request.parameters[1].name == "token")
    }
}

@Suite("Mock Data Tests")
struct MockDataTests {
    @Test func mockDataGeneration() async throws {
        // Configure SDK to use mock data
        let mockConfig = SpatioConfig(useMockData: true)
        SpatioSDK.shared.configure(with: mockConfig)
        
        // Create a test capability
        class TestCapability: BaseRemoteCapability {
            override func configureRequest() -> APIRequest {
                return APIRequest(
                    baseURL: "https://api.example.com",
                    endpoint: "/test",
                    parameters: [
                        APIParameter(name: "q", type: "string", required: true, location: .query)
                    ]
                )
            }
        }
        
        let capability = TestCapability(organization: "test", group: "test", capability: "test")
        let mockData = capability.provideMockData(for: ["q": "test"])
        
        #expect(mockData.contains("mock"))
        #expect(mockData.contains("endpoint"))
        
        // Reset for other tests
        SpatioSDK.shared.reset()
    }
}

@Suite("Capability Tests")
struct CapabilityTests {
    @Test func capabilityInitialization() async throws {
        class TestCapability: BaseRemoteCapability {
            override func configureRequest() -> APIRequest {
                return APIRequest(
                    baseURL: "https://api.example.com",
                    endpoint: "/test"
                )
            }
        }
        
        let capability = TestCapability(
            organization: "test-org",
            group: "test-group",
            capability: "test-capability"
        )
        
        #expect(capability.organization == "test-org")
        #expect(capability.group == "test-group")
        #expect(capability.capability == "test-capability")
        #expect(capability.request.baseURL == "https://api.example.com")
        #expect(capability.request.endpoint == "/test")
    }
    
    @Test func mockDataProviding() async throws {
        // Configure SDK to use mock data
        let mockConfig = SpatioConfig(useMockData: true)
        SpatioSDK.shared.configure(with: mockConfig)
        
        // Create a capability with custom mock data
        class CustomMockCapability: BaseRemoteCapability {
            override func configureRequest() -> APIRequest {
                return APIRequest(
                    baseURL: "https://api.example.com",
                    endpoint: "/test"
                )
            }
            
            override func provideMockData(for params: [String: String]) -> String {
                return """
                {
                    "custom": "mock data",
                    "params": \(params.description)
                }
                """
            }
        }
        
        let capability = CustomMockCapability()
        let result = capability.provideMockData(for: ["query": "test"])
        
        #expect(result.contains("custom"))
        #expect(result.contains("mock data"))
        
        // Reset for other tests
        SpatioSDK.shared.reset()
    }
}

@Suite("Utility Tests")
struct UtilityTests {
    @Test func commandLineArgumentParsing() async throws {
        // Define test parameters
        let parameters = [
            APIParameter(name: "query", type: "string", required: true, location: .query),
            APIParameter(name: "limit", type: "integer", required: false, location: .query, defaultValue: "10"),
            APIParameter(name: "format", type: "string", required: false, location: .query, defaultValue: "json")
        ]
        
        // Parse arguments 
        let namedParams = CommandLineUtils.parseArguments(for: parameters)
        
        // Verify that the params dictionary is not empty
        #expect(!namedParams.isEmpty)
        
        // Verify default values where provided
        if let limitValue = namedParams["limit"] {
            #expect(limitValue == "10")
        }
    }
    
    @Test func resourceUtilsModuleBundle() async throws {
        let bundle = ResourceUtils.moduleBundle()
        #expect(bundle.bundlePath.isEmpty == false)
    }
    
    @Test func loggingSystem() async throws {
        // Reset to ensure default state
        SpatioSDK.shared.reset()
        
        // Confirm default logging level is info
        #expect(Logger.shared.level == .info)
        
        // Configure SDK with debug logging
        let debugConfig = SpatioConfig(loggingLevel: .debug)
        SpatioSDK.shared.configure(with: debugConfig)
        
        // Verify logging level is updated
        #expect(Logger.shared.level == .debug)
        
        // Reset for other tests
        SpatioSDK.shared.reset()
    }
}
