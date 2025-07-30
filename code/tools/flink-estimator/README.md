# 🚀 Flink Resource Estimator

A web-based tool to estimate Apache Flink cluster resource requirements based on your workload characteristics. This FastAPI application provides a user-friendly interface to calculate memory, CPU, and cluster configuration recommendations for your Flink streaming jobs.

## Features

- **Interactive Web Interface**: Clean, modern UI for entering workload parameters
- **Comprehensive Estimation**: Calculates memory, CPU, and cluster requirements
- **Flink Configuration Generator**: Provides ready-to-use Flink configuration snippets
- **RESTful API**: Programmatic access to estimation calculations
- **Responsive Design**: Works on desktop and mobile devices
- **Export Results**: Print or copy configuration for easy sharing
- **Save & Manage Estimations**: Save estimations as JSON files with metadata
- **Download & Preview**: View saved estimations and download them for record keeping

## Quick Start

### Prerequisites

- Python 3.8 or higher
- uv (Python package manager)

### Installation

1. **Navigate to the project directory:**
   ```bash
   cd flink-studies/code/tools/flink-estimator
   ```

2. **Install dependencies:**
   ```bash
   uv pip install -r requirements.txt
   ```

3. **Run the application:**
   ```bash
   uv run main.py
   ```

4. **Access the web interface:**
   Open your browser and go to: http://localhost:8000

## Docker Deployment

### Using Docker Compose (Recommended)

```bash
# Build and run the application
docker-compose up --build

# Run in background
docker-compose up -d --build

# Stop the application
docker-compose down

# View logs
docker-compose logs -f
```

### Using Docker Directly

```bash
# Build the image
docker build -t flink-estimator .

# Run the container
docker run -d \
  --name flink-estimator \
  -p 8000:8000 \
  -v flink_estimations:/app/saved_estimations \
  flink-estimator

# View logs
docker logs -f flink-estimator

# Stop and remove
docker stop flink-estimator && docker rm flink-estimator
```

## Kubernetes Deployment

### Prerequisites
- Kubernetes cluster (local or cloud)
- kubectl configured
- Optional: kustomize for advanced deployments

### Quick Deployment

```bash
# Apply all manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get pods -l app=flink-estimator

# Get service information
kubectl get services

# Access via NodePort (if using NodePort service)
# Application will be available at: http://<node-ip>:30800
```

### Using Kustomize

```bash
# Deploy using kustomize
kubectl apply -k k8s/

# Delete deployment
kubectl delete -k k8s/
```

### Accessing the Application

1. **NodePort Service**: http://\<node-ip\>:30800
2. **Port Forward**: `kubectl port-forward service/flink-estimator-service 8000:80`
3. **Ingress**: Configure ingress controller for production access

## Usage

### Web Interface

1. **Project Information:**
   - Enter your project name for identification

2. **Workload Characteristics:**
   - **Messages per Second**: Expected throughput (e.g., 10,000)
   - **Average Record Size**: Size of each message in bytes (e.g., 1024)

3. **Flink Statement Complexity:**
   - **Simple**: Basic SELECT, WHERE clauses, projections
   - **Medium**: JOINs, GROUP BY, basic window operations
   - **Complex**: Complex windows, CEP patterns, UDFs, nested queries

4. **Submit** and get comprehensive resource recommendations

### API Access

You can also access the estimation programmatically:

```bash
curl "http://localhost:8000/api/estimate?project_name=MyProject&messages_per_second=10000&avg_record_size_bytes=1024&simple_statements=5&medium_statements=2&complex_statements=1"
```

**Or using JSON POST:**

```bash
curl -X POST "http://localhost:8000/api/estimate" \
  -H "Content-Type: application/json" \
  -d '{
    "project_name": "MyProject",
    "messages_per_second": 10000,
    "avg_record_size_bytes": 1024,
    "simple_statements": 5,
    "medium_statements": 2,
    "complex_statements": 1
  }'
```

## Pydantic Data Models

The application uses Pydantic for robust data validation and automatic API documentation. All inputs and outputs are strongly typed with comprehensive validation.

### EstimationInput Model

```python
class EstimationInput(BaseModel):
    project_name: str              # 1-100 characters, non-empty
    messages_per_second: int       # Positive integer
    avg_record_size_bytes: int     # Positive integer
    simple_statements: int = 0     # Non-negative integer
    medium_statements: int = 0     # Non-negative integer  
    complex_statements: int = 0    # Non-negative integer
```

### EstimationResult Model

The response includes nested Pydantic models for:
- **InputSummary**: Validated input parameters with calculated throughput
- **ResourceEstimates**: Memory, CPU, and processing load calculations
- **ClusterRecommendations**: JobManager and TaskManager specifications
- **ScalingRecommendations**: Parallelism and checkpointing settings

### Benefits of Pydantic Integration

- **Automatic Validation**: Input parameters are validated with clear error messages
- **Type Safety**: All data structures are strongly typed
- **API Documentation**: FastAPI automatically generates OpenAPI/Swagger docs
- **JSON Serialization**: Consistent JSON output with proper data types
- **IDE Support**: Full autocomplete and type checking in development

Visit `/docs` when the server is running to see the interactive API documentation.

## Estimation Model

The tool uses a simplified model that considers:

### Resource Calculations

- **Memory Estimation**: Base memory per statement + throughput buffer + complexity overhead
- **CPU Estimation**: Base cores + throughput factor + complexity processing
- **Cluster Sizing**: Optimal JobManager and TaskManager configurations

### Complexity Multipliers

- **Simple Statements**: 1.2x processing overhead
- **Medium Statements**: 2.0x processing overhead  
- **Complex Statements**: 3.5x processing overhead

### Recommendations Include

- **Total Resource Requirements**: Memory and CPU totals
- **Cluster Configuration**: JobManager and TaskManager specs
- **Scaling Parameters**: Parallelism and checkpointing settings
- **Sample Configuration**: Ready-to-use `flink-conf.yaml` snippet

## Example Output

```yaml
# JobManager
jobmanager.memory.process.size: 2048m

# TaskManager  
taskmanager.memory.process.size: 4096m
taskmanager.numberOfTaskSlots: 4

# Checkpointing
execution.checkpointing.interval: 15000ms
execution.checkpointing.mode: EXACTLY_ONCE

# Parallelism
parallelism.default: 8
```

## Persistence & File Management

### Saving Estimations

After generating an estimation, you can save it as a JSON file by clicking the "💾 Save to JSON" button on the results page. Each saved file includes:

- **Metadata**: Unique ID, timestamp, project name
- **Input Parameters**: All the parameters you entered
- **Estimation Results**: Complete calculation results
- **Version Information**: For future compatibility

### JSON File Format

```json
{
  "metadata": {
    "estimation_id": "a1b2c3d4",
    "timestamp": "2024-01-15T10:30:00.000Z",
    "project_name": "My Streaming Project",
    "saved_at": "2024-01-15 10:30:00"
  },
  "input_parameters": {
    "messages_per_second": 10000,
    "avg_record_size_bytes": 1024,
    "simple_statements": 5,
    "medium_statements": 2,
    "complex_statements": 1
  },
  "estimation_results": {
    // Complete estimation results...
  },
  "version": "1.0"
}
```

### Managing Saved Files

- **View All**: Navigate to `/saved` to see all saved estimations
- **Download**: Click download button to get the JSON file
- **Preview**: View file contents in a new window
- **Auto-naming**: Files are automatically named with project, timestamp, and ID

Files are saved in the `saved_estimations/` directory with names like:
`My_Project_20240115_103000_a1b2c3d4.json`

## Project Structure

```
flink-estimator/
├── main.py              # FastAPI application with Pydantic models
├── templates/           # Jinja2 HTML templates
│   ├── index.html       # Main form page
│   ├── results.html     # Results display page
│   └── saved.html       # Saved estimations management page
├── static/              # Static assets
│   └── style.css        # Application styling
├── k8s/                 # Kubernetes manifests
│   ├── deployment.yaml  # Kubernetes deployment
│   ├── service.yaml     # Kubernetes services
│   ├── pvc.yaml         # Persistent volume claim
│   └── kustomization.yaml # Kustomize configuration
├── saved_estimations/   # Directory for saved JSON files (auto-created)
├── requirements.txt     # Python dependencies (includes Pydantic)
├── Dockerfile           # Docker container definition
├── docker-compose.yml   # Docker Compose configuration
├── .dockerignore        # Docker build context exclusions
├── .cursorrules         # Cursor IDE rules for this project
├── .python-version      # Python version specification for uv
└── README.md           # This file
```

## API Reference

### Web Endpoints

- **GET /**: Main estimation form
- **POST /estimate**: Process estimation request (form data)
- **GET /saved**: View saved estimations page

### REST API

- **GET /api/estimate**: Get estimation results (query parameters)
- **POST /api/estimate**: Get estimation results (JSON body with Pydantic model)
- **POST /save-estimation**: Save estimation to JSON file (form data)
- **POST /api/save-estimation**: Save estimation to JSON file (JSON body)
- **GET /download/{filename}**: Download saved estimation file
- **GET /saved-estimations**: List all saved estimation files

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| project_name | str | Yes | Name of the project (1-100 characters) |
| messages_per_second | int | Yes | Expected message throughput (positive) |
| avg_record_size_bytes | int | Yes | Average message size in bytes (positive) |
| simple_statements | int | No | Number of simple SQL statements (≥0) |
| medium_statements | int | No | Number of medium complexity statements (≥0) |
| complex_statements | int | No | Number of complex statements (≥0) |

## Development

### Running in Development Mode

```bash
uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Testing the Application

Run the included test script to validate Pydantic models and core functionality:

```bash
uv run python test_models.py
```

This will test:
- Pydantic model creation and validation
- Estimation calculations  
- JSON serialization and file saving
- Input validation with error handling

### Adding New Features

The application is structured to easily add new estimation models:

1. **Update the `calculate_flink_estimation()` function** in `main.py`
2. **Modify templates** in `templates/` for UI changes
3. **Add styling** in `static/style.css`

## Important Notes

⚠️ **Disclaimer**: This tool provides estimated values based on simplified models. Actual resource requirements may vary significantly based on:

- Specific use case patterns
- Data distribution and skew
- Flink job implementation details
- Network and I/O characteristics
- State management requirements

**Always perform thorough testing and monitoring in your specific environment.**

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is part of the flink-studies repository. Please refer to the main repository license.

## Support

For issues or questions:
1. Check the main flink-studies documentation
2. Review Flink official documentation
3. Create an issue in the repository

---

**Happy Flink Streaming! 🌊** 