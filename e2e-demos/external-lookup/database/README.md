# Claim Database for Lookup Demo

This directory contains the database components for the external lookup demonstration, implementing a Postgresql-based claims database accessible via HTTP API.

## Overview

This implementation provides:

1. **Postgresql Database** - File-based database with claims metadata
2. **HTTP API Wrapper** - FastAPI service to expose DuckDB via REST endpoints  
3. **Docker Container** - Containerized database service
4. **Kubernetes Deployment** - K8s manifests for production-like deployment
5. **Error Simulation** - Configurable failure scenarios for testing

## Components

### Database Schema (`01_create_schema.sql`)
- **claims table** - Insurance claim metadata with indexed lookups
- **active_claims view** - Filtered view excluding denied claims
- Comprehensive indexes for efficient queries

### Sample Data (`02_insert_data.sql`) 
- 25+ realistic claim records for testing
- Mix of claim statuses (APPROVED, PENDING, DENIED, PROCESSING)
- Various claim types (MEDICAL, DENTAL, VISION, LIFE, DISABILITY)
- Test data specifically for payment correlation
- Invalid claim scenarios for error testing

### HTTP API (`claimdb_api.py`)
- **GET /claims/{claim_id}** - Single claim lookup
- **GET /claims** - Multiple claims with filtering
- **GET /health** - Health check with database status
- **GET /stats** - Database statistics
- **POST /simulate/error** - Trigger error simulation
- **POST /simulate/recover** - Recover from errors

### Error Simulation Features
- Configurable error rates (10% default)
- Slow query simulation (5% default)  
- Database unavailability simulation
- Connection timeout scenarios
- Circuit breaker patterns

## Quick Start

### 1. Build the Container
```bash
cd database/
make build
```

### 2. Test Locally
```bash
make run
# OR
docker run -p 8080:8080 --name duckdb -v ./data:/data duckdb-external-lookup:latest
```

### 3. Test the API

```bash
# OpenAPI
chrome http://localhost:8080/docs
# Health check
curl http://localhost:8080/health

# Lookup specific claim
curl http://localhost:8080/claims/CLM-001

# Get statistics
curl http://localhost:8080/stats
```

### 4. Deploy to Kubernetes

```bash
make deploy
# Verify
make status
```
### 5. Clean up
```bash
make undeploy
```

## Kubernetes Deployment

### Persistent Storage

The deployment automatically sets up persistent storage for the DuckDB database:

- **Colima**: Database stored at `/tmp/duckdb-external-lookup` on host
- **kind**: Database stored at `/tmp/hostpath-provisioner/duckdb-external-lookup` on host
- **Auto-detection**: Deployment script detects your K8s environment automatically


### Storage Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  StorageClass   │    │ PersistentVolume │    │      Pod        │
│   (hostpath)    │───▶│   (hostPath)     │───▶│   /data mount   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │   Host Directory │
                       │ /tmp/duckdb-...  │
                       └──────────────────┘
```

## Kubernetes Access

### Internal Cluster Access

```
http://duckdb-external-lookup.default.svc.cluster.local:8080
```

### Port Forward for Testing

```bash
make port-forward
# OR 
kubectl port-forward svc/duckdb-external-lookup 8080:8080
```


## Configuration

Environment variables (set in `k8s/duckdb-configmap.yaml`):

```yaml
API_HOST: "0.0.0.0"
API_PORT: "8080"
SIMULATE_ERRORS: "true"
ERROR_RATE: "0.1"          # 10% error rate
SLOW_QUERY_RATE: "0.05"    # 5% slow queries  
DATABASE_UNAVAILABLE: "false"
```

## Test Scenarios

### Valid Claims (Success Cases)
- `CLM-001` to `CLM-020` - Various claim types and statuses
- `CLAIM-TEST-001` to `CLAIM-TEST-005` - Specific test data

### Invalid Claims (Error Cases)  
- `CLAIM-INVALID-001` - Not in database
- `CLAIM-MISSING-001` - Not in database
- Any non-existent claim_id

### Error Simulation
```bash
# Trigger database unavailability
curl -X POST http://localhost:8080/simulate/error

# Recover from errors
curl -X POST http://localhost:8080/simulate/recover
```

## Performance Characteristics

- **Connection Pool**: 5 concurrent connections
- **Query Timeout**: 5-second timeout for slow queries
- **Error Rate**: Configurable (default 10%)
- **Memory**: 256Mi-1Gi resource limits
- **Storage**: 1Gi persistent volume

## Troubleshooting

### Common Storage Issues

#### PVC Stuck in Pending State

**Problem**: PersistentVolumeClaim remains in "Pending" status

**Solution**:
```bash
# Check deployment status
make status

# Check PVC events
kubectl describe pvc duckdb-pvc

# Verify PV exists
kubectl get pv duckdb-pv

# Recreate if needed
make undeploy
make deploy
```

#### Pod Cannot Start

**Problem**: Pod stuck in "Pending" or "ContainerCreating" status

**Solution**:
```bash
# Check pod events
kubectl describe pod -l app=external-lookup-duckdb

# Verify storage permissions
kubectl exec deployment/duckdb-external-lookup -- ls -la /data 2>/dev/null || echo "Pod not ready"

# Check node resources
kubectl top nodes
```

#### Database Initialization Failed

**Problem**: API health check fails or returns 500 errors

**Solution**:
```bash
# Check pod logs
kubectl logs -l app=external-lookup-duckdb --tail=50

# Test database file
kubectl exec deployment/duckdb-external-lookup -- ls -la /data/

# Restart deployment
kubectl rollout restart deployment/duckdb-external-lookup
```

### Environment-Specific Troubleshooting

#### For Colima:
```bash
# Check Colima status
colima status

# Verify storage path
colima ssh ls -la /tmp/duckdb-external-lookup

# Fix permissions if needed
colima ssh sudo chown -R 65534:65534 /tmp/duckdb-external-lookup
```

### Debugging Commands

```bash
# Complete status overview
make status
# Real-time logs
kubectl logs -l app=external-lookup-duckdb -f

# Interactive pod access
kubectl exec -it deployment/duckdb-external-lookup -- sh

# Manual API test
kubectl exec deployment/duckdb-external-lookup -- curl -f localhost:8080/health

# Storage verification
kubectl get pv,pvc,sc | grep -E "(duckdb|hostpath)"
```
