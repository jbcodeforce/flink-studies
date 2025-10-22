import logging
import os
from pathlib import Path
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
from dotenv import load_dotenv
import httpx
from mcp.server.fastmcp import FastMCP

class FlinkGatewayError(Exception):
    """Base exception for Flink SQL Gateway errors."""
    pass

class SessionError(FlinkGatewayError):
    """Raised for session-related errors."""
    pass

class OperationError(FlinkGatewayError):
    """Raised for operation-related errors."""
    pass

class ConnectionError(FlinkGatewayError):
    """Raised for connection/network errors."""
    pass

# Ensure tmp directory exists
Path("tmp").mkdir(exist_ok=True)

# Configure logging to log to a file
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s", handlers=[
    logging.FileHandler("tmp/mcp_server.log"),
    logging.StreamHandler()
])

logger = logging.getLogger(__name__)

class APIClient:
    """Client for interacting with Flink SQL Gateway REST API."""
    
    def __init__(self, base_url: str):
        """Initialize the API client.
        
        Args:
            base_url: Base URL of the Flink SQL Gateway
            
        Raises:
            ValueError: If base_url is empty or invalid
        """
        if not base_url:
            raise ValueError("Base URL cannot be empty")
            
        self.base_url = base_url.rstrip('/')
        self.client = httpx.Client(timeout=30.0)
        logger.info(f"Initialized API client with base URL: {self.base_url}")
        
    def _make_url(self, endpoint: str) -> str:
        """Construct full URL for an endpoint.
        
        Args:
            endpoint: API endpoint path
            
        Returns:
            Full URL
            
        Raises:
            ValueError: If endpoint is empty or doesn't start with '/'
        """
        if not endpoint or not endpoint.startswith('/'):
            raise ValueError("Endpoint must start with '/'")
        return f"{self.base_url}{endpoint}"
    
    def get(self, endpoint: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Make a GET request to the API.
        
        Args:
            endpoint: API endpoint
            params: Optional query parameters
            
        Returns:
            Response JSON as dictionary
            
        Raises:
            ConnectionError: For network/connection issues
            SessionError: For session-related errors (404, 410)
            OperationError: For operation-related errors
            FlinkGatewayError: For other API errors
        """
        try:
            url = self._make_url(endpoint)
            logger.debug(f"GET {url} params={params}")
            
            response = self.client.get(url, params=params)
            
            if response.status_code in (404, 410):
                raise SessionError(f"Session not found or expired: {response.text}")
            response.raise_for_status()
            
            return response.json()
            
        except httpx.NetworkError as e:
            raise ConnectionError(f"Network error: {e}") from e
        except httpx.HTTPStatusError as e:
            if "operation" in endpoint.lower():
                raise OperationError(f"Operation failed: {e.response.text}") from e
            raise FlinkGatewayError(f"API error: {e.response.text}") from e
    
    def post(self, endpoint: str, json: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Make a POST request to the API.
        
        Args:
            endpoint: API endpoint
            json: Optional JSON body
            
        Returns:
            Response JSON as dictionary
            
        Raises:
            ConnectionError: For network/connection issues
            SessionError: For session-related errors
            OperationError: For operation-related errors
            FlinkGatewayError: For other API errors
        """
        try:
            url = self._make_url(endpoint)
            logger.debug(f"POST {url} json={json}")
            
            response = self.client.post(url, json=json)
            
            if response.status_code in (404, 410):
                raise SessionError(f"Session not found or expired: {response.text}")
            response.raise_for_status()
            
            return response.json()
            
        except httpx.NetworkError as e:
            raise ConnectionError(f"Network error: {e}") from e
        except httpx.HTTPStatusError as e:
            if "operation" in endpoint.lower():
                raise OperationError(f"Operation failed: {e.response.text}") from e
            raise FlinkGatewayError(f"API error: {e.response.text}") from e
        
    def delete(self, endpoint: str) -> Dict[str, Any]:
        """Make a DELETE request to the API.
        
        Args:
            endpoint: API endpoint
            
        Returns:
            Response JSON as dictionary
            
        Raises:
            ConnectionError: For network/connection issues
            SessionError: For session-related errors
            FlinkGatewayError: For other API errors
        """
        try:
            url = self._make_url(endpoint)
            logger.debug(f"DELETE {url}")
            
            response = self.client.delete(url)
            
            if response.status_code in (404, 410):
                raise SessionError(f"Session not found or expired: {response.text}")
            response.raise_for_status()
            
            return response.json()
            
        except httpx.NetworkError as e:
            raise ConnectionError(f"Network error: {e}") from e
        except httpx.HTTPStatusError as e:
            raise FlinkGatewayError(f"API error: {e.response.text}") from e

# Replace with your actual SQL Gateway base URL
SQL_GATEWAY_BASE_URL = "http://localhost:8084"

load_dotenv()
base_url = os.getenv('SQL_GATEWAY_API_BASE_URL', SQL_GATEWAY_BASE_URL)
logger.info(f"Flink MCP Server Connecting to: {base_url}") 

class SessionManager:
    """Manages Flink SQL Gateway sessions."""
    
    def __init__(self):
        self.sessions: Dict[str, Dict[str, Any]] = {}
        
    def add_session(self, session_handle: str) -> None:
        """Add a new session to the manager.
        
        Args:
            session_handle: The session handle to track
        """
        self.sessions[session_handle] = {
            'created_at': datetime.now(),
            'last_used': datetime.now(),
            'operations': {}
        }
        
    def add_operation(self, session_handle: str, operation_handle: str, statement: str) -> None:
        """Track a new operation for a session.
        
        Args:
            session_handle: The session the operation belongs to
            operation_handle: The operation handle to track
            statement: The SQL statement that was executed
        """
        if session_handle in self.sessions:
            self.sessions[session_handle]['operations'][operation_handle] = {
                'created_at': datetime.now(),
                'statement': statement
            }
            self.sessions[session_handle]['last_used'] = datetime.now()
            
    def get_session_info(self, session_handle: str) -> Optional[Dict[str, Any]]:
        """Get information about a session.
        
        Args:
            session_handle: The session to get info for
            
        Returns:
            Session information or None if not found
        """
        return self.sessions.get(session_handle)
        
    def remove_session(self, session_handle: str) -> None:
        """Remove a session from tracking.
        
        Args:
            session_handle: The session to remove
        """
        self.sessions.pop(session_handle, None)
        
    def get_active_sessions(self, max_idle_minutes: int = 60) -> List[str]:
        """Get list of active session handles.
        
        Args:
            max_idle_minutes: Maximum allowed idle time in minutes
            
        Returns:
            List of active session handles
        """
        now = datetime.now()
        max_idle = timedelta(minutes=max_idle_minutes)
        return [
            handle for handle, info in self.sessions.items()
            if now - info['last_used'] <= max_idle
        ]

api = APIClient(base_url)
session_manager = SessionManager()

# Create an MCP server
mcp = FastMCP("Flink SQLGateway MCP Server")

@mcp.tool()
async def execute_a_query(session_handle: str, query: str) -> str:
    """Execute a SQL query statement with the given session handle.

    Args:
        session_handle (str): The session handle returned by open_a_new_session().
        query (str): The SQL query to execute.

    Returns:
        str: A message containing the operation handle for future reference.
    """
    try:
        # Check if session exists
        if not session_manager.get_session_info(session_handle):
            return f"Error: Session {session_handle} not found or expired"
            
        url = f'/v3/sessions/{session_handle}/statements'
        logger.info(f"Executing query: {url} with statement: {query}")
        
        response = api.post(url, {"statement": query})
        operation_handle = response.get('operationHandle')
        
        if operation_handle:
            # Track the operation
            session_manager.add_operation(session_handle, operation_handle, query)
            return f"Operation started successfully. Operation handle: {operation_handle}"
        else:
            return "Error: No operation handle returned"

    except httpx.RequestError as e:
        logger.error(f"Failed to execute query: {e}")
        return f"Request error: {e}"

@mcp.prompt()
def manage_session_handle() -> str:
 return (f"Please check if session_handle already exists. If not, create a new session_handle by calling open_a_new_session(). "
         f"Save the session_handle for future use. "
         f"If there is no session_handle or it has expired, you will need to create a new session_handle by calling open_a_new_session(). Please remember to save it for future use.")

@mcp.tool()
def get_flink_cluster_info() -> str:
    """Get the information of the flink cluster

    Returns:
        a message indicating the flink cluster information.
    """
    try:
        url = f'/v1/info'
        response = api.get(url)
        flink_cluster_info = response.get('clusterInfo')
        return f"flink cluster information: {flink_cluster_info}"
    except httpx.RequestError as e:
        return f"Request error: {e}"
    except Exception as e:
        return f"Error: {e}"

@mcp.tool()
async def open_a_new_session() -> str:
    """Open a new Flink SQL Gateway session.

    Returns:
        str: The session handle for the new session, or an error message if creation failed.
    """
    try:
        url = f'/v1/sessions'
        response = api.post(url)
        session_handle = response.get('sessionHandle')
        
        if session_handle:
            # Track the new session
            session_manager.add_session(session_handle)
            return f"Session created successfully. Session handle: {session_handle}"
        else:
            return "Error: No session handle returned"
            
    except httpx.RequestError as e:
        logger.error(f"Failed to create session: {e}")
        return f"Failed to create session: {e}"
    except Exception as e:
        logger.error(f"Unexpected error creating session: {e}")
        return f"Unexpected error: {e}"

@mcp.tool()
async def close_a_session(session_handle: str) -> str:
    """Close a session with the given session handle.
    
    Args:
        session_handle (str): The session handle to close.
        
    Returns:
        str: A message indicating the session was closed successfully.
    """
    try:
        url = f'/v1/sessions/{session_handle}'
        api.delete(url)
        return f"Session {session_handle} closed successfully"
    except httpx.RequestError as e:
        logger.error(f"Failed to close session {session_handle}: {e}")
        return f"Failed to close session: {e}"

@mcp.tool()
async def fetch_result(session_handle: str, operation_handle: str) -> str:
    """Fetch the result of a SQL operation.
    
    Args:
        session_handle (str): The session handle for the operation.
        operation_handle (str): The operation handle to fetch results for.
        
    Returns:
        str: The operation results as a formatted string.
    """
    try:
        url = f'/v3/sessions/{session_handle}/operations/{operation_handle}/result'
        response = api.get(url)
        
        if 'results' not in response:
            return "No results available"
            
        results = response['results']
        if not results:
            return "Empty result set"
            
        # Format results as a table-like string
        columns = results.get('columns', [])
        data = results.get('data', [])
        
        if not columns or not data:
            return "No data in result set"
            
        # Create header
        header = " | ".join(col.get('name', 'Unknown') for col in columns)
        separator = "-" * len(header)
        
        # Format rows
        rows = []
        for row in data:
            formatted_row = " | ".join(str(val) for val in row)
            rows.append(formatted_row)
            
        # Combine all parts
        table = [header, separator] + rows
        return "\n".join(table)
        
    except httpx.RequestError as e:
        logger.error(f"Failed to fetch results for operation {operation_handle}: {e}")
        return f"Failed to fetch results: {e}"



@mcp.tool()
async def list_active_sessions(max_idle_minutes: int = 60) -> str:
    """List all active sessions and their details.
    
    Args:
        max_idle_minutes: Maximum allowed idle time in minutes
        
    Returns:
        str: Formatted string containing session information
    """
    try:
        active_sessions = session_manager.get_active_sessions(max_idle_minutes)
        
        if not active_sessions:
            return "No active sessions found"
            
        output = ["Active Sessions:"]
        for handle in active_sessions:
            info = session_manager.get_session_info(handle)
            if info:
                created = info['created_at'].strftime('%Y-%m-%d %H:%M:%S')
                last_used = info['last_used'].strftime('%Y-%m-%d %H:%M:%S')
                op_count = len(info['operations'])
                
                output.extend([
                    f"\nSession: {handle}",
                    f"Created: {created}",
                    f"Last Used: {last_used}",
                    f"Operations: {op_count}"
                ])
                
                if op_count > 0:
                    output.append("\nRecent Operations:")
                    for op_handle, op_info in list(info['operations'].items())[-5:]:
                        op_time = op_info['created_at'].strftime('%H:%M:%S')
                        op_stmt = op_info['statement'][:50] + '...' if len(op_info['statement']) > 50 else op_info['statement']
                        output.append(f"- {op_time} [{op_handle}]: {op_stmt}")
                        
        return "\n".join(output)
        
    except Exception as e:
        logger.error(f"Error listing sessions: {e}")
        return f"Error listing sessions: {e}"

if __name__ == "__main__":
    # Run the MCP server
    mcp.run(transport="stdio")


