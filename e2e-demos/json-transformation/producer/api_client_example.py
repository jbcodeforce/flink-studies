#!/usr/bin/env python3
"""
Example client for the Kafka Producer API
"""

import requests
import json
import time
from typing import Dict, Any

# API Configuration
API_BASE_URL = "http://producer-api.local"  # Update this to your API URL
# For local testing: "http://localhost:8000"
# For k8s port-forward: "http://localhost:8080" 

class ProducerAPIClient:
    """Client for interacting with the Kafka Producer API"""
    
    def __init__(self, base_url: str = API_BASE_URL):
        self.base_url = base_url.rstrip('/')
        
    def health_check(self) -> Dict[str, Any]:
        """Check API health status"""
        response = requests.get(f"{self.base_url}/health")
        response.raise_for_status()
        return response.json()
    
    def produce_records(self, record_type: str, topic: str, count: int) -> Dict[str, Any]:
        """Produce records via API"""
        payload = {
            "type": record_type,
            "topic": topic,
            "count": count
        }
        
        response = requests.post(
            f"{self.base_url}/produce",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        response.raise_for_status()
        return response.json()
    
    def produce_custom_json(self, topic: str, data: Dict[str, Any], key: str = None) -> Dict[str, Any]:
        """Produce custom JSON via API"""
        payload = {
            "topic": topic,
            "data": data
        }
        
        if key:
            payload["key"] = key
            
        response = requests.post(
            f"{self.base_url}/produce/custom",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        response.raise_for_status()
        return response.json()
    
    def get_job_status(self, job_id: str) -> Dict[str, Any]:
        """Get job status"""
        response = requests.get(f"{self.base_url}/jobs/{job_id}")
        response.raise_for_status()
        return response.json()
    
    def list_jobs(self) -> list:
        """List all jobs"""
        response = requests.get(f"{self.base_url}/jobs")
        response.raise_for_status()
        return response.json()
    
    def wait_for_job(self, job_id: str, timeout: int = 60) -> Dict[str, Any]:
        """Wait for job completion"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            job = self.get_job_status(job_id)
            
            if job["status"] in ["completed", "failed"]:
                return job
                
            print(f"Job {job_id} status: {job['status']} - {job['message']}")
            time.sleep(2)
        
        raise TimeoutError(f"Job {job_id} did not complete within {timeout} seconds")

def main():
    """Example usage of the API client"""
    
    client = ProducerAPIClient()
    
    print("🔍 Checking API health...")
    try:
        health = client.health_check()
        print(f"✅ API is healthy: {health}")
    except requests.exceptions.RequestException as e:
        print(f"❌ API health check failed: {e}")
        print(f"Make sure the API is running at {API_BASE_URL}")
        return
    
    print("\n" + "="*50)
    
    # Example 1: Produce order records
    print("📦 Example 1: Producing order records...")
    try:
        response = client.produce_records("order", "raw-orders", 5)
        print(f"✅ Job started: {response}")
        
        job_id = response["job_id"]
        print(f"⏳ Waiting for job {job_id} to complete...")
        final_job = client.wait_for_job(job_id)
        print(f"🏁 Job completed: {final_job['status']} - {final_job['message']}")
        
    except Exception as e:
        print(f"❌ Error producing order records: {e}")
    
    print("\n" + "="*50)
    
    # Example 2: Produce job records  
    print("💼 Example 2: Producing job records...")
    try:
        response = client.produce_records("job", "raw-jobs", 3)
        print(f"✅ Job started: {response}")
        
        job_id = response["job_id"]
        print(f"⏳ Waiting for job {job_id} to complete...")
        final_job = client.wait_for_job(job_id)
        print(f"🏁 Job completed: {final_job['status']} - {final_job['message']}")
        
    except Exception as e:
        print(f"❌ Error producing job records: {e}")
    
    print("\n" + "="*50)
    
    # Example 3: Produce custom JSON
    print("🛠️ Example 3: Producing custom JSON...")
    try:
        custom_data = {
            "id": "custom-123",
            "type": "test_event",
            "timestamp": "2024-01-20T10:30:00Z",
            "payload": {
                "user_id": "user_456",
                "action": "api_test",
                "metadata": {
                    "source": "api_client_example",
                    "version": "1.0"
                }
            }
        }
        
        response = client.produce_custom_json("test-topic", custom_data, "custom-123")
        print(f"✅ Custom job started: {response}")
        
        job_id = response["job_id"]
        print(f"⏳ Waiting for custom job {job_id} to complete...")
        final_job = client.wait_for_job(job_id)
        print(f"🏁 Custom job completed: {final_job['status']} - {final_job['message']}")
        
    except Exception as e:
        print(f"❌ Error producing custom JSON: {e}")
    
    print("\n" + "="*50)
    
    # Example 4: List all jobs
    print("📋 Example 4: Listing recent jobs...")
    try:
        jobs = client.list_jobs()
        print(f"📊 Found {len(jobs)} recent jobs:")
        
        for job in jobs[:5]:  # Show last 5 jobs
            status_emoji = {"completed": "✅", "failed": "❌", "running": "⏳", "queued": "📝"}.get(job["status"], "❓")
            print(f"  {status_emoji} {job['job_id']}: {job['status']} - {job['message']}")
            
    except Exception as e:
        print(f"❌ Error listing jobs: {e}")

if __name__ == "__main__":
    main()
