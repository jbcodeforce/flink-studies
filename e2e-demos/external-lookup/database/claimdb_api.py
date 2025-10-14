"""
PostgreSQL HTTP API Wrapper for External Lookup Demo

This FastAPI application provides REST endpoints for accessing PostgreSQL
from external applications like Flink. It simulates database connectivity
issues for testing error handling scenarios.
"""

import os
import time
import random
import logging
from typing import Optional, Dict, Any, List
from contextlib import asynccontextmanager

import psycopg2
from psycopg2.pool import SimpleConnectionPool
from psycopg2.extras import RealDictCursor
from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel


# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database configuration
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "claims")
DB_USER = os.getenv("DB_USER", "claims_user")
DB_PASSWORD = os.getenv("DB_PASSWORD", "claims_password")
CONNECTION_POOL_SIZE = int(os.getenv("CONNECTION_POOL_SIZE", "5"))

# Error simulation configuration  
SIMULATE_ERRORS = os.getenv("SIMULATE_ERRORS", "true").lower() == "true"
ERROR_RATE = float(os.getenv("ERROR_RATE", "0.1"))  # 10% error rate
SLOW_QUERY_RATE = float(os.getenv("SLOW_QUERY_RATE", "0.05"))  # 5% slow queries
DATABASE_UNAVAILABLE = os.getenv("DATABASE_UNAVAILABLE", "false").lower() == "true"

# Global connection pool
connection_pool = None


class ClaimResponse(BaseModel):
    """Response model for claim lookup"""
    claim_id: str
    member_id: str
    claim_amount: float
    claim_status: str
    claim_type: str
    created_date: str
    policy_number: Optional[str] = None
    provider_id: Optional[str] = None


class ErrorResponse(BaseModel):
    """Response model for errors"""
    error: str
    message: str
    claim_id: Optional[str] = None


class HealthResponse(BaseModel):
    """Response model for health check"""
    status: str
    database_status: str
    total_claims: int
    uptime_seconds: float


# Application startup time for uptime calculation
start_time = time.time()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager"""
    # Startup
    logger.info("Starting PostgreSQL API server...")
    init_connection_pool()
    yield
    # Shutdown
    logger.info("Shutting down PostgreSQL API server...")
    close_connection_pool()


app = FastAPI(
    title="PostgreSQL External Lookup API",
    description="REST API for PostgreSQL external lookup demo",
    version="1.0.0",
    lifespan=lifespan
)


def init_connection_pool():
    """Initialize connection pool"""
    global connection_pool
    try:
        connection_pool = SimpleConnectionPool(
            minconn=1,
            maxconn=CONNECTION_POOL_SIZE,
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            cursor_factory=RealDictCursor
        )
        logger.info(f"Initialized connection pool with size {CONNECTION_POOL_SIZE}")
    except Exception as e:
        logger.error(f"Failed to initialize connection pool: {e}")
        raise


def close_connection_pool():
    """Close the connection pool"""
    global connection_pool
    if connection_pool:
        connection_pool.closeall()
        logger.info("Closed all database connections")


def get_connection():
    """Get a connection from the pool"""
    if DATABASE_UNAVAILABLE:
        raise HTTPException(status_code=503, detail="Database is unavailable")
    
    if not connection_pool:
        raise HTTPException(status_code=503, detail="No database connections available")
    
    # Simulate connection errors
    if SIMULATE_ERRORS and random.random() < ERROR_RATE:
        raise HTTPException(status_code=503, detail="Database connection error")
    
    return connection_pool.getconn()


def return_connection(conn):
    """Return a connection to the pool"""
    if conn and connection_pool:
        connection_pool.putconn(conn)


def simulate_slow_query():
    """Simulate slow database queries"""
    if SIMULATE_ERRORS and random.random() < SLOW_QUERY_RATE:
        delay = random.uniform(2.0, 8.0)  # 2-8 second delay
        logger.warning(f"Simulating slow query with {delay:.2f}s delay")
        time.sleep(delay)


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) as count FROM claims")
        result = cur.fetchone()
        total_claims = result['count'] if result else 0
        
        return HealthResponse(
            status="healthy",
            database_status="connected",
            total_claims=total_claims,
            uptime_seconds=time.time() - start_time
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "database_status": "disconnected",
                "total_claims": 0,
                "uptime_seconds": time.time() - start_time,
                "error": str(e)
            }
        )
    finally:
        if conn:
            return_connection(conn)


@app.get("/claims/{claim_id}", response_model=ClaimResponse)
async def get_claim(claim_id: str, request: Request):
    """Get claim details by claim_id"""
    logger.info(f"Looking up claim: {claim_id} from {request.client.host}")
    
    conn = None
    try:
        # Simulate slow queries
        simulate_slow_query()
        
        conn = get_connection()
        cur = conn.cursor()
        cur.execute(
            """
            SELECT claim_id, member_id, claim_amount, claim_status, claim_type, 
                   created_date, policy_number, provider_id
            FROM claims 
            WHERE claim_id = %s
            """,
            (claim_id,)
        )
        result = cur.fetchone()
        
        if not result:
            logger.warning(f"Claim not found: {claim_id}")
            raise HTTPException(
                status_code=404, 
                detail=f"Claim not found: {claim_id}"
            )
        
        claim = ClaimResponse(
            claim_id=result['claim_id'],
            member_id=result['member_id'],
            claim_amount=float(result['claim_amount']),
            claim_status=result['claim_status'],
            claim_type=result['claim_type'],
            created_date=str(result['created_date']),
            policy_number=result['policy_number'],
            provider_id=result['provider_id']
        )
        
        logger.info(f"Successfully returned claim: {claim_id}")
        return claim
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Database error for claim {claim_id}: {e}")
        raise HTTPException(
            status_code=500, 
            detail=f"Database error: {str(e)}"
        )
    finally:
        if conn:
            return_connection(conn)


@app.get("/claims", response_model=List[ClaimResponse])
async def get_claims(
    limit: int = Query(default=10, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    status: Optional[str] = Query(default=None),
    member_id: Optional[str] = Query(default=None)
):
    """Get multiple claims with optional filtering"""
    conn = None
    try:
        simulate_slow_query()
        
        conn = get_connection()
        cur = conn.cursor()
        
        # Build query with filters
        base_query = """
            SELECT claim_id, member_id, claim_amount, claim_status, claim_type, 
                   created_date, policy_number, provider_id
            FROM claims
        """
        
        where_conditions = []
        params = []
        
        if status:
            where_conditions.append("claim_status = %s")
            params.append(status)
        
        if member_id:
            where_conditions.append("member_id = %s")
            params.append(member_id)
        
        if where_conditions:
            base_query += " WHERE " + " AND ".join(where_conditions)
        
        base_query += " ORDER BY created_date DESC LIMIT %s OFFSET %s"
        params.extend([limit, offset])
        
        cur.execute(base_query, params)
        results = cur.fetchall()
        
        claims = [
            ClaimResponse(
                claim_id=row['claim_id'],
                member_id=row['member_id'],
                claim_amount=float(row['claim_amount']),
                claim_status=row['claim_status'],
                claim_type=row['claim_type'],
                created_date=str(row['created_date']),
                policy_number=row['policy_number'],
                provider_id=row['provider_id']
            )
            for row in results
        ]
        
        logger.info(f"Returned {len(claims)} claims")
        return claims
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Database error in get_claims: {e}")
        raise HTTPException(
            status_code=500, 
            detail=f"Database error: {str(e)}"
        )
    finally:
        if conn:
            return_connection(conn)


@app.post("/simulate/error")
async def simulate_error():
    """Endpoint to trigger error simulation for testing"""
    global DATABASE_UNAVAILABLE
    DATABASE_UNAVAILABLE = True
    logger.warning("Simulated database unavailability enabled")
    return {"message": "Database unavailability simulation enabled"}


@app.post("/simulate/recover")
async def simulate_recovery():
    """Endpoint to recover from simulated errors"""
    global DATABASE_UNAVAILABLE
    DATABASE_UNAVAILABLE = False
    logger.info("Database simulation recovered")
    return {"message": "Database simulation recovered"}


@app.get("/stats")
async def get_stats():
    """Get database statistics"""
    conn = None
    try:
        conn = get_connection()
        cur = conn.cursor()
        
        stats = {}
        
        # Total claims
        cur.execute("SELECT COUNT(*) as count FROM claims")
        result = cur.fetchone()
        stats["total_claims"] = result['count']
        
        # Claims by status
        cur.execute(
            "SELECT claim_status, COUNT(*) as count FROM claims GROUP BY claim_status"
        )
        results = cur.fetchall()
        stats["claims_by_status"] = {row['claim_status']: row['count'] for row in results}
        
        # Claims by type
        cur.execute(
            "SELECT claim_type, COUNT(*) as count FROM claims GROUP BY claim_type"
        )
        results = cur.fetchall()
        stats["claims_by_type"] = {row['claim_type']: row['count'] for row in results}
        
        # Average claim amount
        cur.execute("SELECT AVG(claim_amount) as avg FROM claims")
        result = cur.fetchone()
        stats["average_claim_amount"] = float(result['avg']) if result['avg'] else 0.0
        
        return stats
        
    except Exception as e:
        logger.error(f"Error getting stats: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            return_connection(conn)


if __name__ == "__main__":
    import uvicorn
    
    # Get configuration from environment
    host = os.getenv("API_HOST", "0.0.0.0")
    port = int(os.getenv("API_PORT", "8080"))
    
    logger.info(f"Starting server on {host}:{port}")
    logger.info(f"Database connection: postgresql://{DB_USER}:***@{DB_HOST}:{DB_PORT}/{DB_NAME}")
    logger.info(f"Error simulation: {SIMULATE_ERRORS}")
    
    uvicorn.run(
        "claimdb_api:app",
        host=host,
        port=port,
        log_level="info",
        reload=False
    )