import Foundation

/// Specialized generator for Darwin AI core tools
/// Creates the essential file system, execution, and planning tools
public class DarwinCoreToolsGenerator {
    
    private let capabilityGenerator: CapabilityGenerator
    
    public init(mode: PersistenceMode) throws {
        self.capabilityGenerator = try CapabilityGenerator(mode: mode)
    }
    
    /// Generate all Darwin AI core tools
    /// - Parameter overwrite: Whether to overwrite existing tools
    /// - Returns: Array of created core tool capabilities
    /// - Throws: CapabilityGeneratorError if generation fails
    public func generateCoreTools(overwrite: Bool = false) throws -> [DarwinCapabilityMetadata] {
        var createdCapabilities: [DarwinCapabilityMetadata] = []
        
        // First, create the darwin-ai organization if it doesn't exist
        let darwinOrg = createDarwinAIOrganization()
        try capabilityGenerator.createOrganization(darwinOrg, overwrite: overwrite)
        
        // Create core organization for system tools
        let coreOrg = createCoreOrganization()
        try capabilityGenerator.createOrganization(coreOrg, overwrite: overwrite)
        
        // Generate file system tools
        let fileSystemTools = createFileSystemTools()
        for tool in fileSystemTools {
            let created = try capabilityGenerator.createCapability(tool, overwrite: overwrite)
            createdCapabilities.append(created)
        }
        
        // Generate execution tools
        let executionTools = createExecutionTools()
        for tool in executionTools {
            let created = try capabilityGenerator.createCapability(tool, overwrite: overwrite)
            createdCapabilities.append(created)
        }
        
        // Generate planning tools
        let planningTools = createPlanningTools()
        for tool in planningTools {
            let created = try capabilityGenerator.createCapability(tool, overwrite: overwrite)
            createdCapabilities.append(created)
        }
        
        // Generate information tools
        let informationTools = createInformationTools()
        for tool in informationTools {
            let created = try capabilityGenerator.createCapability(tool, overwrite: overwrite)
            createdCapabilities.append(created)
        }
        
        return createdCapabilities
    }
    
    // MARK: - Organization Creation
    
    private func createDarwinAIOrganization() -> DarwinOrganizationData {
        return DarwinOrganizationData(
            id: "darwin-ai",
            name: "Darwin AI",
            description: "Darwin AI core system providing intelligent agentic capabilities",
            types: ["local", "builtin"],
            children: ["core"],
            tags: ["ai", "agent", "system", "darwin"]
        )
    }
    
    private func createCoreOrganization() -> DarwinOrganizationData {
        return DarwinOrganizationData(
            id: "darwin-ai-core",
            name: "Darwin AI Core",
            description: "Core tools for Darwin AI system including file operations, execution, and planning",
            types: ["local", "builtin"],
            tags: ["core", "system", "tools", "builtin"]
        )
    }
    
    // MARK: - File System Tools
    
    private func createFileSystemTools() -> [DarwinCapabilityMetadata] {
        return [
            createReadFileTool(),
            createWriteFileTool(),
            createEditFileTool(),
            createMultiEditTool(),
            createGlobTool(),
            createGrepTool(),
            createLSTool()
        ]
    }
    
    private func createReadFileTool() -> DarwinCapabilityMetadata {
        return DarwinCapabilityMetadata(
            type: "local",
            name: "Read File",
            description: "Read file contents with optional line offset and limit",
            entry_point: "darwin_read_file",
            organization: "darwin-ai-core",
            inputs: [
                DarwinFunctionParameter(
                    name: "file_path",
                    type: "string",
                    required: true,
                    description: "Absolute path to the file to read"
                ),
                DarwinFunctionParameter(
                    name: "offset",
                    type: "integer",
                    required: false,
                    description: "Line number to start reading from (1-based)"
                ),
                DarwinFunctionParameter(
                    name: "limit",
                    type: "integer",
                    required: false,
                    description: "Maximum number of lines to read"
                )
            ],
            output: DarwinCapabilityOutput(
                type: "string",
                description: "File contents with line numbers"
            ),
            auth_type: .none
        )
    }
    
    private func createWriteFileTool() -> DarwinCapabilityMetadata {
        return DarwinCapabilityMetadata(
            type: "local",
            name: "Write File",
            description: "Write content to a file, creating it if it doesn't exist",
            entry_point: "darwin_write_file",
            organization: "darwin-ai-core",
            inputs: [
                DarwinFunctionParameter(
                    name: "file_path",
                    type: "string",
                    required: true,
                    description: "Absolute path to the file to write"
                ),
                DarwinFunctionParameter(
                    name: "content",
                    type: "string",
                    required: true,
                    description: "Content to write to the file"
                )
            ],
            output: DarwinCapabilityOutput(
                type: "object",
                description: "Result of file write operation"
            ),
            auth_type: .none
        )
    }
    
    private func createEditFileTool() -> DarwinCapabilityMetadata {
        return DarwinCapabilityMetadata(
            type: "local",
            name: "Edit File",
            description: "Make precise edits to existing files using find and replace",
            entry_point: "darwin_edit_file",
            organization: "darwin-ai-core",
            inputs: [
                DarwinFunctionParameter(
                    name: "file_path",
                    type: "string",
                    required: true,
                    description: "Absolute path to the file to edit"
                ),
                DarwinFunctionParameter(
                    name: "old_string",
                    type: "string",
                    required: true,
                    description: "Text to replace (must match exactly)"
                ),
                DarwinFunctionParameter(
                    name: "new_string",
                    type: "string",
                    required: true,
                    description: "Text to replace it with"
                ),
                DarwinFunctionParameter(
                    name: "replace_all",
                    type: "boolean",
                    required: false,
                    defaultValue: "false",
                    description: "Replace all occurrences (default: false)"
                )
            ],
            output: DarwinCapabilityOutput(
                type: "object",
                description: "Result of file edit operation"
            ),
            auth_type: .none
        )
    }
    
    private func createMultiEditTool() -> DarwinCapabilityMetadata {
        return DarwinCapabilityMetadata(
            type: "local",
            name: "Multi Edit File",
            description: "Make multiple edits to a single file in one operation",
            entry_point: "darwin_multi_edit_file",
            organization: "darwin-ai-core",
            inputs: [
                DarwinFunctionParameter(
                    name: "file_path",
                    type: "string",
                    required: true,
                    description: "Absolute path to the file to edit"
                ),
                DarwinFunctionParameter(
                    name: "edits",
                    type: "array",
                    required: true,
                    description: "Array of edit operations to perform"
                )
            ],
            output: DarwinCapabilityOutput(
                type: "object",
                description: "Result of multi-edit operation"
            ),
            auth_type: .none
        )
    }
    
    private func createGlobTool() -> DarwinCapabilityMetadata {
        return DarwinCapabilityMetadata(
            type: "local",
            name: "Find Files by Pattern",
            description: "Find files matching a glob pattern",
            entry_point: "darwin_glob",
            organization: "darwin-ai-core",
            inputs: [
                DarwinFunctionParameter(
                    name: "pattern",
                    type: "string",
                    required: true,
                    description: "Glob pattern to match files against (e.g., '**/*.swift')"
                ),
                DarwinFunctionParameter(
                    name: "path",
                    type: "string",
                    required: false,
                    description: "Directory to search in (defaults to current directory)"
                )
            ],
            output: DarwinCapabilityOutput(
                type: "array",
                description: "Array of matching file paths"
            ),
            auth_type: .none
        )
    }
    
    private func createGrepTool() -> DarwinCapabilityMetadata {
        return DarwinCapabilityMetadata(
            type: "local",
            name: "Search File Contents",
            description: "Search file contents using regular expressions",
            entry_point: "darwin_grep",
            organization: "darwin-ai-core",
            inputs: [
                DarwinFunctionParameter(
                    name: "pattern",
                    type: "string",
                    required: true,
                    description: "Regular expression pattern to search for"
                ),
                DarwinFunctionParameter(
                    name: "path",
                    type: "string",
                    required: false,
                    description: "Directory to search in (defaults to current directory)"
                ),
                DarwinFunctionParameter(
                    name: "include",
                    type: "string",
                    required: false,
                    description: "File pattern to include in search (e.g., '*.swift')"
                )
            ],
            output: DarwinCapabilityOutput(
                type: "array",
                description: "Array of files containing matches"
            ),
            auth_type: .none
        )
    }
    
    private func createLSTool() -> DarwinCapabilityMetadata {
        return DarwinCapabilityMetadata(
            type: "local",
            name: "List Directory",
            description: "List files and directories in a given path",
            entry_point: "darwin_ls",
            organization: "darwin-ai-core",
            inputs: [
                DarwinFunctionParameter(
                    name: "path",
                    type: "string",
                    required: true,
                    description: "Absolute path to the directory to list"
                ),
                DarwinFunctionParameter(
                    name: "ignore",
                    type: "array",
                    required: false,
                    description: "Array of glob patterns to ignore"
                )
            ],
            output: DarwinCapabilityOutput(
                type: "array",
                description: "Array of file and directory names"
            ),
            auth_type: .none
        )
    }
    
    // MARK: - Execution Tools
    
    private func createExecutionTools() -> [DarwinCapabilityMetadata] {
        return [
            createBashTool(),
            createTaskTool()
        ]
    }
    
    private func createBashTool() -> DarwinCapabilityMetadata {
        return DarwinCapabilityMetadata(
            type: "local",
            name: "Execute Command",
            description: "Execute shell commands in a persistent session",
            entry_point: "darwin_bash",
            organization: "darwin-ai-core",
            inputs: [
                DarwinFunctionParameter(
                    name: "command",
                    type: "string",
                    required: true,
                    description: "The command to execute"
                ),
                DarwinFunctionParameter(
                    name: "description",
                    type: "string",
                    required: false,
                    description: "Description of what this command does"
                ),
                DarwinFunctionParameter(
                    name: "timeout",
                    type: "integer",
                    required: false,
                    defaultValue: "120000",
                    description: "Timeout in milliseconds (max 600000)"
                )
            ],
            output: DarwinCapabilityOutput(
                type: "object",
                description: "Command execution result with stdout, stderr, and exit code"
            ),
            auth_type: .none
        )
    }
    
    private func createTaskTool() -> DarwinCapabilityMetadata {
        return DarwinCapabilityMetadata(
            type: "local",
            name: "Launch Task Agent",
            description: "Launch a specialized agent for complex searches and operations",
            entry_point: "darwin_task",
            organization: "darwin-ai-core",
            inputs: [
                DarwinFunctionParameter(
                    name: "description",
                    type: "string",
                    required: true,
                    description: "Short description of the task (3-5 words)"
                ),
                DarwinFunctionParameter(
                    name: "prompt",
                    type: "string",
                    required: true,
                    description: "Detailed task description for the agent"
                )
            ],
            output: DarwinCapabilityOutput(
                type: "string",
                description: "Task execution result from the agent"
            ),
            auth_type: .none
        )
    }
    
    // MARK: - Planning Tools
    
    private func createPlanningTools() -> [DarwinCapabilityMetadata] {
        return [
            createTodoWriteTool(),
            createExitPlanModeTool()
        ]
    }
    
    private func createTodoWriteTool() -> DarwinCapabilityMetadata {
        return DarwinCapabilityMetadata(
            type: "local",
            name: "Manage Task List",
            description: "Create and manage a structured task list for tracking progress",
            entry_point: "darwin_todo_write",
            organization: "darwin-ai-core",
            inputs: [
                DarwinFunctionParameter(
                    name: "todos",
                    type: "array",
                    required: true,
                    description: "Array of todo items with id, content, status, and priority"
                )
            ],
            output: DarwinCapabilityOutput(
                type: "object",
                description: "Updated task list with status information"
            ),
            auth_type: .none
        )
    }
    
    private func createExitPlanModeTool() -> DarwinCapabilityMetadata {
        return DarwinCapabilityMetadata(
            type: "local",
            name: "Exit Plan Mode",
            description: "Transition from planning to execution mode",
            entry_point: "darwin_exit_plan_mode",
            organization: "darwin-ai-core",
            inputs: [
                DarwinFunctionParameter(
                    name: "plan",
                    type: "string",
                    required: true,
                    description: "The plan to present for user approval"
                )
            ],
            output: DarwinCapabilityOutput(
                type: "object",
                description: "Plan approval result"
            ),
            auth_type: .none
        )
    }
    
    // MARK: - Information Tools
    
    private func createInformationTools() -> [DarwinCapabilityMetadata] {
        return [
            createWebSearchTool(),
            createWebFetchTool()
        ]
    }
    
    private func createWebSearchTool() -> DarwinCapabilityMetadata {
        return DarwinCapabilityMetadata(
            type: "local",
            name: "Web Search",
            description: "Search the web and return formatted results",
            entry_point: "darwin_web_search",
            organization: "darwin-ai-core",
            inputs: [
                DarwinFunctionParameter(
                    name: "query",
                    type: "string",
                    required: true,
                    description: "The search query to use"
                ),
                DarwinFunctionParameter(
                    name: "allowed_domains",
                    type: "array",
                    required: false,
                    description: "Only include results from these domains"
                ),
                DarwinFunctionParameter(
                    name: "blocked_domains",
                    type: "array",
                    required: false,
                    description: "Never include results from these domains"
                )
            ],
            output: DarwinCapabilityOutput(
                type: "array",
                description: "Array of search results with titles, URLs, and snippets"
            ),
            auth_type: .none
        )
    }
    
    private func createWebFetchTool() -> DarwinCapabilityMetadata {
        return DarwinCapabilityMetadata(
            type: "local",
            name: "Web Fetch",
            description: "Fetch and analyze web content with AI processing",
            entry_point: "darwin_web_fetch",
            organization: "darwin-ai-core",
            inputs: [
                DarwinFunctionParameter(
                    name: "url",
                    type: "string",
                    required: true,
                    description: "The URL to fetch content from"
                ),
                DarwinFunctionParameter(
                    name: "prompt",
                    type: "string",
                    required: true,
                    description: "The prompt to run on the fetched content"
                )
            ],
            output: DarwinCapabilityOutput(
                type: "string",
                description: "Processed content based on the prompt"
            ),
            auth_type: .none
        )
    }
}