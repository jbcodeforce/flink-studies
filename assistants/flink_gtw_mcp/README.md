# Flink SQL Gateway MCP Server

This MCP server provides a convenient interface to interact with Apache Flink's SQL Gateway REST API. It enables executing SQL queries, managing sessions, and retrieving results through a simple set of tools.

## Features

- Session Management
  - Create and close sessions
  - Track session activity and operations
  - List active sessions with their details
- Query Execution
  - Execute SQL queries with session tracking
  - Fetch and format query results
  - Monitor operation status
- Error Handling
  - Comprehensive error reporting
  - Session validation
  - Operation tracking

## Installation

1. Ensure you have Python 3.8+ installed
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Configuration

The server can be configured using environment variables:

- `SQL_GATEWAY_API_BASE_URL`: Base URL of the Flink SQL Gateway (default: http://localhost:8084)

You can also create a `.env` file in the project directory:

```env
SQL_GATEWAY_API_BASE_URL=http://your-gateway:8084
```

## Available Tools

### 1. Open Session
```python
open_a_new_session() -> str
```
Creates a new Flink SQL Gateway session and returns the session handle.

### 2. Execute Query
```python
execute_a_query(session_handle: str, query: str) -> str
```
Executes a SQL query in the specified session and returns an operation handle.

### 3. Fetch Results
```python
fetch_result(session_handle: str, operation_handle: str) -> str
```
Retrieves and formats the results of a completed operation.

### 4. Close Session
```python
close_a_session(session_handle: str) -> str
```
Closes a session and cleans up resources.

### 5. List Active Sessions
```python
list_active_sessions(max_idle_minutes: int = 60) -> str
```
Lists all active sessions with their details and recent operations.

## Example Usage

1. Start a new session:
```python
session = await open_a_new_session()
# Session created successfully. Session handle: abc-123
```

2. Execute a query:
```python
result = await execute_a_query(session, "SELECT * FROM my_table")
# Operation started successfully. Operation handle: op-456
```

3. Fetch results:
```python
data = await fetch_result(session, "op-456")
# Results displayed in table format
```

4. List active sessions:
```python
sessions = await list_active_sessions()
# Displays active sessions and their details
```

5. Close session:
```python
await close_a_session(session)
# Session abc-123 closed successfully
```

## Error Handling

The server implements comprehensive error handling:

- Network errors are caught and logged
- Invalid session handles are detected
- Operation failures are reported with details
- All errors are logged to `tmp/mcp_server.log`

## Session Management

Sessions are automatically tracked with:
- Creation time
- Last used timestamp
- Operation history
- Automatic cleanup of idle sessions

## Development

To run the server in development mode:

```bash
python main.py
```

The server will start and listen for commands via stdio.

## Logging

Logs are written to `tmp/mcp_server.log` and include:
- Query execution details
- Session management events
- Error reports
- Operation tracking

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
