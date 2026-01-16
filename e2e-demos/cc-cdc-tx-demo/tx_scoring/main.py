"""
Transaction Scoring Service
FastAPI endpoint for ML-based transaction fraud scoring
"""

import os
import time
from datetime import datetime
from typing import Tuple, Annotated
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
import logging

# Configure logging
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Bearer Token Authentication
security = HTTPBearer()
BEARER_TOKEN = os.getenv("BEARER_TOKEN", "")

def verify_token(credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)]) -> str:
    """
    Verify bearer token from Authorization header.
    
    Args:
        credentials: HTTPAuthorizationCredentials from the Authorization header
        
    Returns:
        The token if valid
        
    Raises:
        HTTPException: If token is missing or invalid
    """
    if not BEARER_TOKEN:
        logger.warning("BEARER_TOKEN not configured - authentication disabled")
        return credentials.credentials
    
    if credentials.credentials != BEARER_TOKEN:
        logger.warning(f"Invalid token attempt from client")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return credentials.credentials

# Initialize FastAPI app
app = FastAPI(
    title="Transaction Scoring Service",
    description="ML-based fraud detection scoring for card transactions",
    version="0.1.0"
)

# Add security scheme to OpenAPI docs
app.openapi_schema = None  # Force regeneration

def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    from fastapi.openapi.utils import get_openapi
    openapi_schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
    )
    # Add security scheme
    openapi_schema["components"]["securitySchemes"] = {
        "Bearer": {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "token",
            "description": "Bearer token authentication"
        }
    }
    # Apply security to /predict endpoint
    for path, path_item in openapi_schema["paths"].items():
        if path == "/predict":
            path_item["post"]["security"] = [{"Bearer": []}]
    app.openapi_schema = openapi_schema
    return app.openapi_schema

app.openapi = custom_openapi


# Request/Response Models
class TransactionRequest(BaseModel):
    """Request model for transaction scoring"""
    txn_id: str = Field(..., description="Unique transaction identifier")
    account_number: str = Field(..., description="Account number")
    amount: float = Field(..., gt=0, description="Transaction amount")
    merchant: str = Field(..., description="Merchant name")
    location: str = Field(..., description="Transaction location")
    tx_time: datetime = Field(..., description="Transaction timestamp")

    class Config:
        json_schema_extra = {
            "example": {
                "txn_id": "txn-12345",
                "account_number": "1234567890",
                "amount": 150.50,
                "merchant": "AMAZON",
                "location": "ONLINE",
                "tx_time": "2021-01-01T00:00:00Z"
            }
        }


class FraudScoreResponse(BaseModel):
    """Response model for fraud scoring"""
    txn_id: str = Field(..., description="Transaction identifier")
    fraud_score: float = Field(..., ge=0.0, le=1.0, description="Fraud probability score (0-1)")
    fraud_category: str = Field(..., description="Category of fraud risk")
    risk_level: str = Field(..., description="Risk level: LOW, MEDIUM, HIGH")
    inference_timestamp: float = Field(..., description="Unix timestamp of inference")

    class Config:
        json_schema_extra = {
            "example": {
                "txn_id": "txn-12345",
                "fraud_score": 0.25,
                "fraud_category": "NORMAL",
                "risk_level": "LOW",
                "inference_timestamp": 1704067200.0
            }
        }


class HealthResponse(BaseModel):
    """Health check response model"""
    status: str = Field(..., description="Service status")
    timestamp: float = Field(..., description="Current timestamp")


# ML Model Simulation
# TODO: Replace with actual Random Forest model
def predict_fraud_score(request: TransactionRequest) -> Tuple[float, str, str]:
    """
    Simulate ML model prediction for fraud scoring.
    
    This is a placeholder implementation that will be replaced with
    a real Random Forest model in a future enhancement.
    
    Args:
        request: TransactionRequest object containing all transaction details
        
    Returns:
        Tuple of (fraud_score, fraud_category, risk_level)
    """
    # Simple rule-based scoring for simulation
    # TODO: Replace with actual ML model inference
    # Future ML model can use all fields: request.amount, request.merchant, 
    # request.location, request.account_number, request.tx_time, etc.
    
    fraud_score = 0.1  # Default low risk
    
    # Rule 1: High amount transactions
    if request.amount > 1000:
        fraud_score = 0.7
        category = "AMOUNT_ANOMALY"
        risk_level = "HIGH"
    # Rule 2: Medium-high online transactions
    elif request.amount > 500 and request.location.upper() == "ONLINE":
        fraud_score = 0.5
        category = "ONLINE_HIGH_VALUE"
        risk_level = "MEDIUM"
    # Rule 3: Medium amount transactions
    elif request.amount > 500:
        fraud_score = 0.3
        category = "HIGH_VALUE"
        risk_level = "MEDIUM"
    else:
        fraud_score = 0.1
        category = "NORMAL"
        risk_level = "LOW"
    
    return fraud_score, category, risk_level


# API Endpoints
@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    """
    Health check endpoint for service monitoring.
    Used by ECS health checks and load balancers.
    """
    return {
        "status": "healthy",
        "timestamp": time.time()
    }


@app.post("/predict", response_model=FraudScoreResponse, tags=["Scoring"])
async def score_transaction(
    request: TransactionRequest,
    token: Annotated[str, Depends(verify_token)]
):
    """
    Score a transaction for fraud risk.
    
    Accepts transaction details and returns fraud score, category, and risk level.
    This endpoint will be called by Flink SQL jobs for real-time transaction enrichment.
    
    Args:
        request: Transaction details (txn_id, account_number, amount, merchant, location, tx_time)
        
    Returns:
        Fraud scoring results with score, category, and risk level
    """
    try:
        logger.info(f"Scoring transaction: {request.txn_id}, amount: {request.amount}")
        
        # Get fraud prediction
        fraud_score, fraud_category, risk_level = predict_fraud_score(request)
        
        response = FraudScoreResponse(
            txn_id=request.txn_id,
            fraud_score=round(fraud_score, 4),
            fraud_category=fraud_category,
            risk_level=risk_level,
            inference_timestamp=time.time()
        )
        
        logger.info(
            f"Transaction {request.txn_id} scored: "
            f"score={response.fraud_score}, category={response.fraud_category}, "
            f"risk={response.risk_level}"
        )
        
        return response
        
    except Exception as e:
        logger.error(f"Error scoring transaction {request.txn_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@app.get("/", tags=["Info"])
async def root():
    """Root endpoint with API information"""
    return {
        "service": "Transaction Scoring Service",
        "version": "0.1.0",
        "endpoints": {
            "health": "/health",
            "predict": "/predict",
            "docs": "/docs",
            "openapi": "/openapi.json"
        }
    }


if __name__ == "__main__":
    import uvicorn
    
    port = int(os.getenv("PORT", "8080"))
    host = os.getenv("HOST", "0.0.0.0")
    
    # HTTPS Configuration
    ssl_keyfile = os.getenv("SSL_KEYFILE")
    ssl_certfile = os.getenv("SSL_CERTFILE")
    
    ssl_config = {}
    if ssl_keyfile and ssl_certfile:
        ssl_config = {
            "ssl_keyfile": ssl_keyfile,
            "ssl_certfile": ssl_certfile,
        }
        logger.info(f"HTTPS enabled with certificate: {ssl_certfile}")
    else:
        logger.warning("HTTPS not configured - SSL_KEYFILE and SSL_CERTFILE not set")
    
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        log_level=os.getenv("LOG_LEVEL", "info").lower(),
        **ssl_config
    )
