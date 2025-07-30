from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field, field_validator
from typing import Annotated, Optional
import math
import json
import os
from datetime import datetime
import uuid

app = FastAPI(title="Flink Resource Estimator", description="Tool to estimate Flink cluster resources based on workload parameters")

# Mount static files and templates
app.mount("/static", StaticFiles(directory="static"), name="static")
templates = Jinja2Templates(directory="templates")

# Create saved estimations directory
SAVED_ESTIMATIONS_DIR = "saved_estimations"
os.makedirs(SAVED_ESTIMATIONS_DIR, exist_ok=True)

# Pydantic Models
class EstimationInput(BaseModel):
    """Input parameters for Flink estimation"""
    project_name: str = Field(..., min_length=1, max_length=100, description="Name of the project")
    messages_per_second: int = Field(..., gt=0, description="Expected messages per second")
    avg_record_size_bytes: int = Field(..., gt=0, description="Average record size in bytes")
    simple_statements: int = Field(default=0, ge=0, description="Number of simple statements")
    medium_statements: int = Field(default=0, ge=0, description="Number of medium complexity statements")
    complex_statements: int = Field(default=0, ge=0, description="Number of complex statements")
    
    @field_validator('project_name')
    def validate_project_name(cls, v):
        if not v or v.isspace():
            raise ValueError('Project name cannot be empty or just whitespace')
        return v.strip()
    
    @property
    def total_statements(self) -> int:
        return self.simple_statements + self.medium_statements + self.complex_statements
    
    @property
    def total_throughput_mb_per_sec(self) -> float:
        return (self.messages_per_second * self.avg_record_size_bytes) / (1024 * 1024)

class InputSummary(BaseModel):
    """Summary of input parameters with calculated values"""
    messages_per_second: int
    avg_record_size_bytes: int
    total_throughput_mb_per_sec: float
    simple_statements: int
    medium_statements: int
    complex_statements: int
    total_statements: int

class ResourceEstimates(BaseModel):
    """Estimated resource requirements"""
    total_memory_mb: int
    total_cpu_cores: int
    processing_load_score: float

class JobManagerConfig(BaseModel):
    """JobManager configuration specifications"""
    memory_mb: int
    cpu_cores: int

class TaskManagerConfig(BaseModel):
    """TaskManager configuration specifications"""
    count: int
    memory_mb_each: int
    cpu_cores_each: int
    total_memory_mb: int
    total_cpu_cores: int

class ClusterRecommendations(BaseModel):
    """Cluster configuration recommendations"""
    jobmanager: JobManagerConfig
    taskmanagers: TaskManagerConfig

class ScalingRecommendations(BaseModel):
    """Scaling and performance recommendations"""
    min_parallelism: int
    recommended_parallelism: int
    max_parallelism: int
    checkpointing_interval_ms: int

class EstimationResult(BaseModel):
    """Complete estimation result"""
    input_summary: InputSummary
    resource_estimates: ResourceEstimates
    cluster_recommendations: ClusterRecommendations
    scaling_recommendations: ScalingRecommendations

class EstimationMetadata(BaseModel):
    """Metadata for saved estimations"""
    estimation_id: str
    timestamp: str
    project_name: str
    saved_at: str

class SavedEstimation(BaseModel):
    """Complete saved estimation data structure"""
    metadata: EstimationMetadata
    input_parameters: EstimationInput
    estimation_results: EstimationResult
    version: str = "1.0"

def save_estimation_to_json(
    input_params: EstimationInput,
    estimation_result: EstimationResult
) -> str:
    """
    Save estimation data to a JSON file with timestamp and unique ID.
    Returns the filename of the saved file.
    """
    
    # Generate unique identifier and timestamp
    estimation_id = str(uuid.uuid4())[:8]
    timestamp = datetime.now().isoformat()
    
    # Create metadata
    metadata = EstimationMetadata(
        estimation_id=estimation_id,
        timestamp=timestamp,
        project_name=input_params.project_name,
        saved_at=datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    )
    
    # Create complete saved estimation object
    saved_estimation = SavedEstimation(
        metadata=metadata,
        input_parameters=input_params,
        estimation_results=estimation_result
    )
    
    # Create filename with project name and timestamp
    safe_project_name = "".join(c for c in input_params.project_name if c.isalnum() or c in (' ', '-', '_')).rstrip()
    safe_project_name = safe_project_name.replace(' ', '_')
    timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"{safe_project_name}_{timestamp_str}_{estimation_id}.json"
    filepath = os.path.join(SAVED_ESTIMATIONS_DIR, filename)
    
    # Save to file using Pydantic's JSON serialization
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(saved_estimation.model_dump_json(indent=2))
    
    return filename

def calculate_flink_estimation(input_params: EstimationInput) -> EstimationResult:
    """
    Calculate Flink resource estimation based on input parameters.
    This is a simplified estimation model.
    """
    
    # Use properties from EstimationInput for calculations
    total_throughput_mb = input_params.total_throughput_mb_per_sec
    
    # Complexity multipliers (processing overhead)
    simple_multiplier = 1.2
    medium_multiplier = 2.0
    complex_multiplier = 3.5
    
    # Calculate processing load
    processing_load = (
        input_params.simple_statements * simple_multiplier +
        input_params.medium_statements * medium_multiplier +
        input_params.complex_statements * complex_multiplier
    )
    
    # Memory estimation (MB)
    # Base memory per statement + buffer for throughput
    base_memory_per_statement = 512  # MB
    throughput_memory_factor = total_throughput_mb * 2  # Buffer factor
    
    total_memory_mb = (
        input_params.total_statements * base_memory_per_statement +
        throughput_memory_factor +
        processing_load * 100  # Additional memory for complex processing
    )
    
    # CPU estimation (cores)
    # Base CPU + processing complexity + throughput factor
    base_cpu_cores = 2
    throughput_cpu_factor = math.ceil(total_throughput_mb / 50)  # 1 core per 50MB/s
    complexity_cpu = math.ceil(processing_load / 2)
    
    total_cpu_cores = base_cpu_cores + throughput_cpu_factor + complexity_cpu
    
    # TaskManager recommendations
    taskmanager_memory_mb = min(8192, max(2048, total_memory_mb // 2))  # 2-8GB per TM
    taskmanager_cpu_cores = min(8, max(2, total_cpu_cores // 2))  # 2-8 cores per TM
    
    # Number of TaskManagers needed
    num_taskmanagers = max(2, math.ceil(total_memory_mb / taskmanager_memory_mb))
    
    # JobManager specs (usually fixed)
    jobmanager_memory_mb = max(1024, min(4096, total_memory_mb // 8))
    jobmanager_cpu_cores = 2
    
    # Create Pydantic models for the result
    input_summary = InputSummary(
        messages_per_second=input_params.messages_per_second,
        avg_record_size_bytes=input_params.avg_record_size_bytes,
        total_throughput_mb_per_sec=round(total_throughput_mb, 2),
        simple_statements=input_params.simple_statements,
        medium_statements=input_params.medium_statements,
        complex_statements=input_params.complex_statements,
        total_statements=input_params.total_statements
    )
    
    resource_estimates = ResourceEstimates(
        total_memory_mb=math.ceil(total_memory_mb),
        total_cpu_cores=total_cpu_cores,
        processing_load_score=round(processing_load, 2)
    )
    
    jobmanager_config = JobManagerConfig(
        memory_mb=jobmanager_memory_mb,
        cpu_cores=jobmanager_cpu_cores
    )
    
    taskmanager_config = TaskManagerConfig(
        count=num_taskmanagers,
        memory_mb_each=taskmanager_memory_mb,
        cpu_cores_each=taskmanager_cpu_cores,
        total_memory_mb=num_taskmanagers * taskmanager_memory_mb,
        total_cpu_cores=num_taskmanagers * taskmanager_cpu_cores
    )
    
    cluster_recommendations = ClusterRecommendations(
        jobmanager=jobmanager_config,
        taskmanagers=taskmanager_config
    )
    
    scaling_recommendations = ScalingRecommendations(
        min_parallelism=max(1, total_cpu_cores // 2),
        recommended_parallelism=total_cpu_cores,
        max_parallelism=total_cpu_cores * 2,
        checkpointing_interval_ms=min(60000, max(5000, 10000 + int(processing_load * 1000)))
    )
    
    return EstimationResult(
        input_summary=input_summary,
        resource_estimates=resource_estimates,
        cluster_recommendations=cluster_recommendations,
        scaling_recommendations=scaling_recommendations
    )


@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    """Serve the main estimation form."""
    return templates.TemplateResponse("index.html", {"request": request})


@app.get("/saved", response_class=HTMLResponse)
async def saved_estimations_page(request: Request):
    """Serve the saved estimations page."""
    return templates.TemplateResponse("saved.html", {"request": request})


@app.post("/estimate", response_class=HTMLResponse)
async def estimate_resources(
    request: Request,
    project_name: Annotated[str, Form()],
    messages_per_second: Annotated[int, Form()],
    avg_record_size_bytes: Annotated[int, Form()],
    simple_statements: Annotated[int, Form()] = 0,
    medium_statements: Annotated[int, Form()] = 0,
    complex_statements: Annotated[int, Form()] = 0
):
    """Process the estimation request and return results."""
    
    try:
        # Create EstimationInput from form data
        input_params = EstimationInput(
            project_name=project_name,
            messages_per_second=messages_per_second,
            avg_record_size_bytes=avg_record_size_bytes,
            simple_statements=simple_statements,
            medium_statements=medium_statements,
            complex_statements=complex_statements
        )
        
        # Calculate estimation using Pydantic models
        estimation_result = calculate_flink_estimation(input_params)
        
        return templates.TemplateResponse(
            "results.html", 
            {
                "request": request,
                "project_name": project_name,
                "estimation": estimation_result,
                "success": True
            }
        )
    except Exception as e:
        return templates.TemplateResponse(
            "results.html",
            {
                "request": request,
                "project_name": project_name if 'project_name' in locals() else "Unknown",
                "error": str(e),
                "success": False
            }
        )


@app.get("/api/estimate")
async def api_estimate(
    project_name: str,
    messages_per_second: int,
    avg_record_size_bytes: int,
    simple_statements: int = 0,
    medium_statements: int = 0,
    complex_statements: int = 0
):
    """API endpoint for programmatic access to estimation via query parameters."""
    try:
        input_params = EstimationInput(
            project_name=project_name,
            messages_per_second=messages_per_second,
            avg_record_size_bytes=avg_record_size_bytes,
            simple_statements=simple_statements,
            medium_statements=medium_statements,
            complex_statements=complex_statements
        )
        return calculate_flink_estimation(input_params)
    except Exception as e:
        return JSONResponse({
            "error": str(e),
            "message": "Invalid input parameters"
        }, status_code=400)


@app.post("/api/estimate")
async def api_estimate_post(input_params: EstimationInput):
    """API endpoint for programmatic access to estimation via JSON."""
    try:
        return calculate_flink_estimation(input_params)
    except Exception as e:
        return JSONResponse({
            "error": str(e),
            "message": "Failed to calculate estimation"
        }, status_code=500)


@app.post("/save-estimation")
async def save_estimation(
    project_name: Annotated[str, Form()],
    messages_per_second: Annotated[int, Form()],
    avg_record_size_bytes: Annotated[int, Form()],
    simple_statements: Annotated[int, Form()] = 0,
    medium_statements: Annotated[int, Form()] = 0,
    complex_statements: Annotated[int, Form()] = 0
):
    """Save estimation results to JSON file."""
    try:
        # Create EstimationInput from form data
        input_params = EstimationInput(
            project_name=project_name,
            messages_per_second=messages_per_second,
            avg_record_size_bytes=avg_record_size_bytes,
            simple_statements=simple_statements,
            medium_statements=medium_statements,
            complex_statements=complex_statements
        )
        
        # Calculate estimation using Pydantic models
        estimation_result = calculate_flink_estimation(input_params)
        
        # Save to JSON using Pydantic models
        filename = save_estimation_to_json(input_params, estimation_result)
        
        return JSONResponse({
            "success": True,
            "message": f"Estimation saved successfully as {filename}",
            "filename": filename
        })
        
    except Exception as e:
        return JSONResponse({
            "success": False,
            "message": f"Error saving estimation: {str(e)}"
        }, status_code=500)


@app.post("/api/save-estimation")
async def api_save_estimation(input_params: EstimationInput):
    """API endpoint to save estimation via JSON."""
    try:
        # Calculate estimation using Pydantic models
        estimation_result = calculate_flink_estimation(input_params)
        
        # Save to JSON using Pydantic models
        filename = save_estimation_to_json(input_params, estimation_result)
        
        return JSONResponse({
            "success": True,
            "message": f"Estimation saved successfully as {filename}",
            "filename": filename
        })
        
    except Exception as e:
        return JSONResponse({
            "success": False,
            "message": f"Error saving estimation: {str(e)}"
        }, status_code=500)


@app.get("/download/{filename}")
async def download_estimation(filename: str):
    """Download a saved estimation JSON file."""
    filepath = os.path.join(SAVED_ESTIMATIONS_DIR, filename)
    
    if not os.path.exists(filepath):
        return JSONResponse({
            "error": "File not found"
        }, status_code=404)
    
    return FileResponse(
        filepath,
        media_type="application/json",
        filename=filename
    )


@app.get("/reload/{filename}", response_class=HTMLResponse)
async def reload_estimation(request: Request, filename: str):
    """Reload a saved estimation and display the results page."""
    filepath = os.path.join(SAVED_ESTIMATIONS_DIR, filename)
    
    if not os.path.exists(filepath):
        return templates.TemplateResponse(
            "results.html",
            {
                "request": request,
                "project_name": "Unknown",
                "error": f"Estimation file '{filename}' not found",
                "success": False
            }
        )
    
    try:
        # Load the saved estimation file
        with open(filepath, 'r', encoding='utf-8') as f:
            saved_data = json.load(f)
        
        # Parse the saved estimation using Pydantic models
        saved_estimation = SavedEstimation(**saved_data)
        
        return templates.TemplateResponse(
            "results.html",
            {
                "request": request,
                "project_name": saved_estimation.input_parameters.project_name,
                "estimation": saved_estimation.estimation_results,
                "success": True,
                "is_reloaded": True,
                "saved_filename": filename,
                "saved_at": saved_estimation.metadata.saved_at
            }
        )
        
    except Exception as e:
        return templates.TemplateResponse(
            "results.html",
            {
                "request": request,
                "project_name": "Unknown",
                "error": f"Error loading estimation: {str(e)}",
                "success": False
            }
        )


@app.get("/saved-estimations")
async def list_saved_estimations():
    """List all saved estimation files."""
    try:
        files = []
        for filename in os.listdir(SAVED_ESTIMATIONS_DIR):
            if filename.endswith('.json'):
                filepath = os.path.join(SAVED_ESTIMATIONS_DIR, filename)
                stat = os.stat(filepath)
                
                # Try to read metadata from file
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                        project_name = data.get('metadata', {}).get('project_name', 'Unknown')
                        saved_at = data.get('metadata', {}).get('saved_at', 'Unknown')
                except:
                    project_name = 'Unknown'
                    saved_at = 'Unknown'
                
                files.append({
                    "filename": filename,
                    "project_name": project_name,
                    "saved_at": saved_at,
                    "size_bytes": stat.st_size,
                    "modified_time": datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
                })
        
        # Sort by modification time (newest first)
        files.sort(key=lambda x: x['modified_time'], reverse=True)
        
        return JSONResponse({
            "success": True,
            "files": files,
            "count": len(files)
        })
        
    except Exception as e:
        return JSONResponse({
            "success": False,
            "message": f"Error listing files: {str(e)}"
        }, status_code=500)


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 