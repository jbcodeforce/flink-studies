#!/usr/bin/env python3
"""
Reusable JSON Schema Generator for Pydantic Models

This script can generate JSON schemas for any Pydantic model.
Usage:
    python generate_json_schema.py <model_module> <model_class> [output_file]

Examples:
    # Generate schema for PaymentEvent model
    python generate_json_schema.py src.event_generator.models PaymentEvent
    
    # Generate schema with custom output file
    python generate_json_schema.py src.event_generator.models PaymentEvent payment_schema.json
    
    # Generate schema for any other model
    python generate_json_schema.py my_module MyModel my_model_schema.json
"""

import json
import sys
import importlib
from pathlib import Path
from typing import Any, Type
from pydantic import BaseModel


def import_model_class(module_path: str, class_name: str) -> Type[BaseModel]:
    """
    Dynamically import a Pydantic model class.
    
    Args:
        module_path: Python module path (e.g., 'src.event_generator.models')
        class_name: Name of the Pydantic model class (e.g., 'PaymentEvent')
        
    Returns:
        The imported Pydantic model class
        
    Raises:
        ImportError: If module or class cannot be imported
        TypeError: If the imported class is not a Pydantic model
    """
    try:
        module = importlib.import_module(module_path)
        model_class = getattr(module, class_name)
        
        if not issubclass(model_class, BaseModel):
            raise TypeError(f"{class_name} is not a Pydantic BaseModel")
            
        return model_class
    except ImportError as e:
        raise ImportError(f"Could not import {module_path}: {e}")
    except AttributeError:
        raise ImportError(f"Class {class_name} not found in module {module_path}")


def generate_schema(model_class: Type[BaseModel], output_file: str = None) -> dict:
    """
    Generate JSON schema for a Pydantic model.
    
    Args:
        model_class: The Pydantic model class
        output_file: Optional output file path
        
    Returns:
        The generated JSON schema as a dictionary
    """
    # Generate the JSON schema
    schema = model_class.model_json_schema()
    
    # Pretty print the schema to console
    print(f"JSON Schema for {model_class.__name__}:")
    print("=" * 50)
    print(json.dumps(schema, indent=2))
    
    # Save to file if specified
    if output_file:
        output_path = Path(output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w') as f:
            json.dump(schema, f, indent=2)
        
        print(f"\nSchema saved to: {output_path.absolute()}")
    
    return schema


def main():
    """Main CLI interface"""
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    
    module_path = sys.argv[1]
    class_name = sys.argv[2]
    output_file = sys.argv[3] if len(sys.argv) > 3 else f"{class_name.lower()}_schema.json"
    
    try:
        # Import the model class
        model_class = import_model_class(module_path, class_name)
        
        # Generate the schema
        generate_schema(model_class, output_file)
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
