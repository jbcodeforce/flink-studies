#!/usr/bin/env python3
"""
FastAPI REST API for Kafka JSON Producer
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, List
import asyncio
import threading
import time
from enum import Enum
import logging
import uuid
import os

from kafka_json_producer import produce_records, produce_custom_json

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# FastAPI app instance
app = FastAPI(
    title="Kafka JSON Producer API",
    description="REST API for producing JSON records to Kafka topics",
    version="1.0.0"
)

# Templates configuration
templates = Jinja2Templates(directory="templates")

# Static files configuration
app.mount("/static", StaticFiles(directory="static"), name="static")

class RecordType(str, Enum):
    """Supported record types"""
    JOB = "job"
    ORDER = "order"

class ProduceRequest(BaseModel):
    """Request model for producing records"""
    type: RecordType = Field(..., description="Type of record to produce")
    topic: str = Field(..., description="Kafka topic name")
    count: int = Field(..., gt=0, le=1000, description="Number of records to produce (1-1000)")

class CustomProduceRequest(BaseModel):
    """Request model for producing custom JSON records"""
    topic: str = Field(..., description="Kafka topic name")
    data: Dict[str, Any] = Field(..., description="Custom JSON data to produce")
    key: Optional[str] = Field(None, description="Optional message key")

class ProduceResponse(BaseModel):
    """Response model for produce operations"""
    job_id: str = Field(..., description="Unique job identifier")
    status: str = Field(..., description="Job status")
    message: str = Field(..., description="Status message")
    request_details: Dict[str, Any] = Field(..., description="Details of the request")

class JobStatus(BaseModel):
    """Job status information"""
    job_id: str
    status: str  # "running", "completed", "failed"
    message: str
    started_at: float
    completed_at: Optional[float] = None
    records_produced: int = 0
    request_details: Dict[str, Any]

# In-memory job tracking (in production, you'd use Redis or similar)
active_jobs: Dict[str, JobStatus] = {}

def run_producer_job(job_id: str, record_type: str, topic: str, count: int):
    """Run producer job in background thread"""
    job = active_jobs[job_id]
    
    try:
        logger.info(f"Starting producer job {job_id}: {record_type} -> {topic} (count: {count})")
        job.status = "running"
        
        # Call the existing producer function
        produce_records(record_type, topic, count)
        
        job.status = "completed"
        job.message = f"Successfully produced {count} {record_type} records to {topic}"
        job.records_produced = count
        job.completed_at = time.time()
        
        logger.info(f"Completed producer job {job_id}")
        
    except Exception as e:
        job.status = "failed"
        job.message = f"Failed to produce records: {str(e)}"
        job.completed_at = time.time()
        logger.error(f"Producer job {job_id} failed: {e}")

def run_custom_producer_job(job_id: str, topic: str, data: Dict[str, Any], key: Optional[str]):
    """Run custom producer job in background thread"""
    job = active_jobs[job_id]
    
    try:
        logger.info(f"Starting custom producer job {job_id}: -> {topic}")
        job.status = "running"
        
        # Call the existing custom producer function
        produce_custom_json(data, topic, key)
        
        job.status = "completed" 
        job.message = f"Successfully produced custom JSON to {topic}"
        job.records_produced = 1
        job.completed_at = time.time()
        
        logger.info(f"Completed custom producer job {job_id}")
        
    except Exception as e:
        job.status = "failed"
        job.message = f"Failed to produce custom JSON: {str(e)}"
        job.completed_at = time.time()
        logger.error(f"Custom producer job {job_id} failed: {e}")

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    """Serve the main web interface"""
    return templates.TemplateResponse("home.html", {"request": request})

@app.get("/job-history", response_class=HTMLResponse)
async def job_history(request: Request):
    """Serve the job history page"""
    return templates.TemplateResponse("job_history.html", {"request": request})

@app.get("/demo-description", response_class=HTMLResponse)
async def demo_description(request: Request):
    """Serve the demonstration description page"""
    return templates.TemplateResponse("demo_description.html", {"request": request})

@app.get("/api")
async def api_info():
    """API information endpoint"""
    return {
        "service": "Kafka JSON Producer API",
        "status": "healthy",
        "version": "1.0.0",
        "documentation": {
            "swagger": "/docs",
            "redoc": "/redoc"
        },
        "endpoints": {
            "produce_records": "POST /produce",
            "produce_custom": "POST /produce/custom",
            "list_jobs": "GET /jobs",
            "get_job": "GET /jobs/{job_id}",
            "health_check": "GET /health"
        }
    }

@app.get("/health")
async def health_check():
    """Detailed health check"""
    try:
        # Try to import required modules to verify dependencies
        import confluent_kafka
        import pydantic
        
        return {
            "status": "healthy",
            "dependencies": {
                "confluent_kafka": "available",
                "pydantic": "available"
            },
            "active_jobs": len([j for j in active_jobs.values() if j.status == "running"])
        }
    except ImportError as e:
        raise HTTPException(status_code=503, detail=f"Service unhealthy: {e}")

@app.post("/produce", response_model=ProduceResponse)
async def produce_records_endpoint(request: ProduceRequest, background_tasks: BackgroundTasks):
    """Produce records to Kafka topic"""
    
    # Generate unique job ID
    job_id = f"job_{int(time.time())}_{uuid.uuid4().hex[:8]}"
    
    # Create job tracking entry
    job = JobStatus(
        job_id=job_id,
        status="queued",
        message=f"Queued {request.count} {request.type} records for {request.topic}",
        started_at=time.time(),
        request_details={
            "type": request.type,
            "topic": request.topic,
            "count": request.count
        }
    )
    active_jobs[job_id] = job
    
    # Start background task
    background_tasks.add_task(
        run_producer_job,
        job_id,
        request.type.value,
        request.topic,
        request.count
    )
    
    return ProduceResponse(
        job_id=job_id,
        status="queued",
        message=f"Started producing {request.count} {request.type} records to {request.topic}",
        request_details=job.request_details
    )

@app.post("/produce/custom", response_model=ProduceResponse)
async def produce_custom_endpoint(request: CustomProduceRequest, background_tasks: BackgroundTasks):
    """Produce custom JSON data to Kafka topic"""
    
    # Generate unique job ID
    job_id = f"custom_{int(time.time())}_{uuid.uuid4().hex[:8]}"
    
    # Create job tracking entry
    job = JobStatus(
        job_id=job_id,
        status="queued", 
        message=f"Queued custom JSON for {request.topic}",
        started_at=time.time(),
        request_details={
            "type": "custom",
            "topic": request.topic,
            "key": request.key,
            "data_keys": list(request.data.keys())
        }
    )
    active_jobs[job_id] = job
    
    # Start background task
    background_tasks.add_task(
        run_custom_producer_job,
        job_id,
        request.topic,
        request.data,
        request.key
    )
    
    return ProduceResponse(
        job_id=job_id,
        status="queued",
        message=f"Started producing custom JSON to {request.topic}",
        request_details=job.request_details
    )

@app.get("/jobs/{job_id}", response_model=JobStatus)
async def get_job_status(job_id: str):
    """Get status of a specific job"""
    
    if job_id not in active_jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    
    return active_jobs[job_id]

@app.get("/jobs", response_model=List[JobStatus])
async def list_jobs():
    """List all jobs (recent first)"""
    
    jobs = list(active_jobs.values())
    jobs.sort(key=lambda x: x.started_at, reverse=True)
    
    # Return last 50 jobs to avoid overwhelming response
    return jobs[:50]

@app.delete("/jobs/{job_id}")
async def delete_job(job_id: str):
    """Delete a job from tracking (completed/failed jobs only)"""
    
    if job_id not in active_jobs:
        raise HTTPException(status_code=404, detail="Job not found")
    
    job = active_jobs[job_id]
    
    if job.status == "running":
        raise HTTPException(status_code=400, detail="Cannot delete running job")
    
    del active_jobs[job_id]
    
    return {"message": f"Job {job_id} deleted successfully"}

@app.post("/jobs/cleanup")
async def cleanup_completed_jobs():
    """Clean up completed and failed jobs older than 1 hour"""
    
    current_time = time.time()
    cutoff_time = current_time - 3600  # 1 hour ago
    
    jobs_to_delete = []
    for job_id, job in active_jobs.items():
        if job.status in ["completed", "failed"] and job.started_at < cutoff_time:
            jobs_to_delete.append(job_id)
    
    for job_id in jobs_to_delete:
        del active_jobs[job_id]
    
    return {
        "message": f"Cleaned up {len(jobs_to_delete)} old jobs",
        "deleted_jobs": jobs_to_delete
    }

if __name__ == "__main__":
    import uvicorn
    
    # Run the FastAPI server
    uvicorn.run(
        "api_server:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info"
    )
