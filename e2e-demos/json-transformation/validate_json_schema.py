#!/usr/bin/env python3
"""
JSON Schema Validator for OrderDetails

This script validates JSON data against the simple.json schema and provides
comprehensive validation reporting and testing capabilities.

Usage:
    python validate_json_schema.py --schema schema.json --data data.json
    python validate_json_schema.py --test-all  # Run all tests with existing data
    python validate_json_schema.py --interactive  # Interactive validation mode

Requirements:
    pip install jsonschema
"""

import json
import sys
import argparse
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
import traceback

try:
    from jsonschema import validate, ValidationError, Draft202012Validator
    from jsonschema.exceptions import SchemaError
except ImportError:
    print("Error: jsonschema library is required. Install with: pip install jsonschema")
    sys.exit(1)


class JSONSchemaValidator:
    """Comprehensive JSON Schema Validator"""
    
    def __init__(self, schema_path: str):
        """Initialize validator with schema file"""
        self.schema_path = Path(schema_path)
        self.schema = self._load_schema()
        self.validator = Draft202012Validator(self.schema)
    
    def _load_schema(self) -> Dict[str, Any]:
        """Load and validate schema file"""
        try:
            with open(self.schema_path, 'r', encoding='utf-8') as f:
                schema = json.load(f)
            
            # Validate the schema itself
            Draft202012Validator.check_schema(schema)
            print(f"✓ Schema loaded successfully from {self.schema_path}")
            return schema
            
        except FileNotFoundError:
            raise FileNotFoundError(f"Schema file not found: {self.schema_path}")
        except json.JSONDecodeError as e:
            raise ValueError(f"Invalid JSON in schema file: {e}")
        except SchemaError as e:
            raise ValueError(f"Invalid JSON Schema: {e}")
    
    def validate_data(self, data_path: str) -> Tuple[bool, List[str]]:
        """
        Validate JSON data against schema
        
        Returns:
            Tuple of (is_valid, error_messages)
        """
        try:
            with open(data_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            return self._validate_json_object(data, data_path)
            
        except FileNotFoundError:
            return False, [f"Data file not found: {data_path}"]
        except json.JSONDecodeError as e:
            return False, [f"Invalid JSON in data file {data_path}: {e}"]
    
    def _validate_json_object(self, data: Dict[str, Any], source: str = "data") -> Tuple[bool, List[str]]:
        """Validate a JSON object against the schema"""
        errors = []
        
        try:
            validate(instance=data, schema=self.schema)
            return True, []
            
        except ValidationError as e:
            # Collect all validation errors
            for error in sorted(self.validator.iter_errors(data), key=str):
                error_path = " -> ".join([str(p) for p in error.absolute_path]) if error.absolute_path else "root"
                error_msg = f"Path: {error_path} | Error: {error.message}"
                if hasattr(error, 'validator_value'):
                    error_msg += f" | Expected: {error.validator_value}"
                errors.append(error_msg)
            
            return False, errors
    
    def validate_string(self, json_string: str) -> Tuple[bool, List[str]]:
        """Validate JSON string against schema"""
        try:
            data = json.loads(json_string)
            return self._validate_json_object(data, "string input")
        except json.JSONDecodeError as e:
            return False, [f"Invalid JSON string: {e}"]
    
    def get_schema_info(self) -> str:
        """Get formatted schema information"""
        info = []
        info.append(f"Schema Title: {self.schema.get('title', 'N/A')}")
        info.append(f"Schema Description: {self.schema.get('description', 'N/A')}")
        info.append(f"Schema ID: {self.schema.get('$id', 'N/A')}")
        info.append(f"Required Properties: {self.schema.get('required', [])}")
        
        if 'properties' in self.schema:
            info.append("Properties:")
            for prop_name, prop_def in self.schema['properties'].items():
                prop_type = prop_def.get('type', 'unknown')
                prop_desc = prop_def.get('description', '')
                info.append(f"  - {prop_name} ({prop_type}): {prop_desc}")
        
        return "\n".join(info)


def create_sample_valid_data() -> Dict[str, Any]:
    """Create sample data that matches the simple.json schema"""
    return {
        "OrderDetails": {
            "OrderId": 12345,
            "Status": "Active",
            "Equipment": [
                {
                    "ModelCode": "TRK001",
                    "Rate": "45.99"
                },
                {
                    "ModelCode": "TRL002", 
                    "Rate": "25.50"
                }
            ],
            "TotalPaid": 71.49
        }
    }


def run_comprehensive_tests(validator: JSONSchemaValidator, base_dir: Path):
    """Run comprehensive tests with existing data files"""
    print("\n" + "="*60)
    print("COMPREHENSIVE VALIDATION TESTS")
    print("="*60)
    
    # Test existing data files
    data_dir = base_dir / "data"
    test_files = [
        "order_detail.json",
        "expected_order_details.json", 
        "enriched_order_detail.json"
    ]
    
    results = []
    
    for file_name in test_files:
        file_path = data_dir / file_name
        if file_path.exists():
            print(f"\nTesting: {file_name}")
            print("-" * 40)
            is_valid, errors = validator.validate_data(str(file_path))
            
            if is_valid:
                print("✓ VALID - Data matches schema")
                results.append((file_name, True, []))
            else:
                print("✗ INVALID - Validation errors found:")
                for i, error in enumerate(errors, 1):
                    print(f"  {i}. {error}")
                results.append((file_name, False, errors))
        else:
            print(f"\nSkipping: {file_name} (file not found)")
    
    # Test sample valid data
    print(f"\nTesting: Sample Valid Data")
    print("-" * 40)
    sample_data = create_sample_valid_data()
    is_valid, errors = validator._validate_json_object(sample_data, "sample")
    
    if is_valid:
        print("✓ VALID - Sample data matches schema")
        results.append(("sample_data", True, []))
    else:
        print("✗ INVALID - Sample data validation errors:")
        for i, error in enumerate(errors, 1):
            print(f"  {i}. {error}")
        results.append(("sample_data", False, errors))
    
    # Summary
    print(f"\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    
    valid_count = sum(1 for _, is_valid, _ in results if is_valid)
    total_count = len(results)
    
    print(f"Total files tested: {total_count}")
    print(f"Valid files: {valid_count}")
    print(f"Invalid files: {total_count - valid_count}")
    
    if valid_count == total_count:
        print("\n🎉 All tests passed!")
    else:
        print(f"\n⚠️  {total_count - valid_count} test(s) failed")
        
    return results


def interactive_mode(validator: JSONSchemaValidator):
    """Interactive validation mode"""
    print("\n" + "="*60)
    print("INTERACTIVE VALIDATION MODE")
    print("="*60)
    print("Enter JSON data to validate (or 'quit' to exit)")
    print("For multiline JSON, end with a line containing only '###'")
    print()
    
    while True:
        try:
            print("Enter JSON data:")
            lines = []
            while True:
                line = input()
                if line.strip() == '###':
                    break
                if line.strip().lower() == 'quit':
                    return
                lines.append(line)
            
            if not lines:
                continue
                
            json_string = '\n'.join(lines)
            is_valid, errors = validator.validate_string(json_string)
            
            if is_valid:
                print("✓ VALID - JSON data matches schema\n")
            else:
                print("✗ INVALID - Validation errors:")
                for i, error in enumerate(errors, 1):
                    print(f"  {i}. {error}")
                print()
                
        except KeyboardInterrupt:
            print("\nExiting interactive mode...")
            break
        except Exception as e:
            print(f"Error: {e}\n")


def main():
    parser = argparse.ArgumentParser(
        description="JSON Schema Validator for OrderDetails",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --schema cp-flink/simple.json --data data/expected_order_details.json
  %(prog)s --test-all
  %(prog)s --interactive
  %(prog)s --schema-info
        """
    )
    
    parser.add_argument('--schema', '-s', 
                       default='cp-flink/simple.json',
                       help='Path to JSON schema file (default: cp-flink/simple.json)')
    parser.add_argument('--data', '-d',
                       help='Path to JSON data file to validate')
    parser.add_argument('--test-all', '-t',
                       action='store_true',
                       help='Run comprehensive tests with all existing data files')
    parser.add_argument('--interactive', '-i',
                       action='store_true', 
                       help='Enter interactive validation mode')
    parser.add_argument('--schema-info',
                       action='store_true',
                       help='Display schema information')
    parser.add_argument('--create-sample', 
                       help='Create a sample valid JSON file at specified path')
    
    args = parser.parse_args()
    
    # Determine base directory and schema path
    base_dir = Path(__file__).parent
    schema_path = base_dir / args.schema
    
    try:
        # Initialize validator
        validator = JSONSchemaValidator(str(schema_path))
        
        # Display schema info if requested
        if args.schema_info:
            print("\n" + "="*60)
            print("SCHEMA INFORMATION") 
            print("="*60)
            print(validator.get_schema_info())
            print()
        
        # Create sample data if requested
        if args.create_sample:
            sample_data = create_sample_valid_data()
            sample_path = Path(args.create_sample)
            with open(sample_path, 'w', encoding='utf-8') as f:
                json.dump(sample_data, f, indent=2)
            print(f"✓ Sample valid data created at: {sample_path}")
            return
        
        # Run tests based on arguments
        if args.test_all:
            run_comprehensive_tests(validator, base_dir)
        elif args.interactive:
            interactive_mode(validator)
        elif args.data:
            data_path = base_dir / args.data
            print(f"Validating: {data_path}")
            print("-" * 40)
            
            is_valid, errors = validator.validate_data(str(data_path))
            
            if is_valid:
                print("✓ VALID - Data matches schema")
            else:
                print("✗ INVALID - Validation errors found:")
                for i, error in enumerate(errors, 1):
                    print(f"  {i}. {error}")
                sys.exit(1)
        else:
            # Default: show help and schema info
            parser.print_help()
            print(f"\n" + "="*60)
            print("SCHEMA INFORMATION")
            print("="*60) 
            print(validator.get_schema_info())
    
    except Exception as e:
        print(f"Error: {e}")
        if "--debug" in sys.argv:
            traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
