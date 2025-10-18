import unittest
from models import generate_job_record, generate_order_record, Order, Job
from decimal import Decimal
import json

class TestRecordGeneration(unittest.TestCase):
    def test_job_record_generation(self):
        """Test job record generation and serialization"""
        try:
            # Generate a job record
            key, job = generate_job_record()
            
            # Basic validation
            self.assertIsInstance(job, Job)
            self.assertIsInstance(key, int)
            
            # Test numeric fields
            self.assertIsInstance(job.rate_service_provider, float)
            self.assertIsInstance(job.total_paid, float)
            
            # Test serialization to ensure it can be sent to Kafka
            job_dict = job.model_dump()
            job_json = json.dumps(job_dict)
            
            print("\n=== Job Record Test ===")
            print(f"Key: {key}")
            print(f"Job Record JSON: {job_json}")
            
        except Exception as e:
            self.fail(f"Job record generation failed: {str(e)}")

    def test_order_record_generation(self):
        """Test order record generation and serialization"""
        try:
            # Generate an order record
            key, order = generate_order_record()
            
            # Basic validation
            self.assertIsInstance(order, Order)
            self.assertIsInstance(key, int)
            
            # Validate Equipment list
            self.assertIsNotNone(order.Equipment)
            self.assertTrue(len(order.Equipment) > 0)
            
            # Test numeric fields
            self.assertIsInstance(order.TotalPaid, float)
            
            # Validate Equipment rates
            for equipment in order.Equipment:
                print(f"\nEquipment Rate (before): {equipment.Rate}")
                # Convert rate to float to check if it's valid
                rate_float = float(equipment.Rate)
                print(f"Equipment Rate (after): {rate_float}")
            
            # Test full serialization
            order_dict = order.model_dump()
            order_json = json.dumps(order_dict)
            
            print("\n=== Order Record Test ===")
            print(f"Key: {key}")
            print(f"Order Record JSON: {order_json}")
            
            # Deserialize back to ensure it's valid
            deserialized_dict = json.loads(order_json)
            deserialized_order = Order(**deserialized_dict)
            
        except Exception as e:
            self.fail(f"Order record generation failed: {str(e)}")
            
    def test_equipment_rate_conversion(self):
        """Specific test for equipment rate conversion"""
        try:
            _, order = generate_order_record()
            
            print("\n=== Equipment Rate Test ===")
            for idx, equipment in enumerate(order.Equipment):
                print(f"\nEquipment {idx + 1}:")
                print(f"Model Code: {equipment.ModelCode}")
                print(f"Rate (original): {equipment.Rate}")
                print(f"Rate type: {type(equipment.Rate)}")
                
                # Try converting to different numeric types
                try:
                    float_rate = float(equipment.Rate)
                    print(f"Rate as float: {float_rate}")
                except ValueError as e:
                    print(f"Float conversion failed: {e}")
                
                try:
                    decimal_rate = Decimal(equipment.Rate)
                    print(f"Rate as Decimal: {decimal_rate}")
                except Exception as e:
                    print(f"Decimal conversion failed: {e}")
                    
        except Exception as e:
            self.fail(f"Equipment rate test failed: {str(e)}")

if __name__ == '__main__':
    unittest.main()
