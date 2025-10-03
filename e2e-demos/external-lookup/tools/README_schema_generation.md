# JSON Schema Generator for Pydantic Models

This directory contains reusable scripts for generating JSON schemas from Pydantic models.

## Scripts

### 1. `generate_json_schema.py` - Dynamic Schema Generator

A flexible script that can generate JSON schemas for any Pydantic model by importing it dynamically.

**Usage:**
```bash
python generate_json_schema.py <module_path> <class_name> [output_file]
```

**Examples:**
```bash
# Generate schema for PaymentEvent model
python generate_json_schema.py src.event_generator.models PaymentEvent

# Generate with custom output file
python generate_json_schema.py src.event_generator.models PaymentEvent custom_schema.json

# Generate for any other model
python generate_json_schema.py my_module MyModel my_schema.json
```

**Features:**
- Works with any Pydantic model in your project
- Automatic output file naming if not specified
- Creates output directories automatically
- Error handling for import issues

### 2. `generate_standalone_schemas.py` - Standalone Generator

A self-contained script that includes model definitions inline. Use this when you have import issues or want a portable solution.

**Usage:**
```bash
python generate_standalone_schemas.py
```

**Features:**
- No external dependencies (beyond pydantic)
- Easy to modify for different models
- Creates schemas directory automatically
- Good for one-off schema generation

**To add more models:**
1. Add your Pydantic model class definitions to the script
2. Add a call to `generate_schema_for_model()` in the `main()` function

## Output

Both scripts generate JSON schemas that include:
- Complete field definitions with types and descriptions
- Enum definitions in `$defs` section
- Required vs optional field specifications
- Default values where applicable
- Validation constraints (e.g., minimum values)

## Generated Schema Structure

```json
{
  "$defs": {
    "EnumName": {
      "description": "Enum description",
      "enum": ["VALUE1", "VALUE2"],
      "title": "EnumName",
      "type": "string"
    }
  },
  "description": "Model description",
  "properties": {
    "field_name": {
      "description": "Field description",
      "title": "Field Name",
      "type": "string"
    }
  },
  "required": ["required_field1", "required_field2"],
  "title": "ModelName",
  "type": "object"
}
```

## Use Cases

The generated JSON schemas can be used for:
- API documentation (OpenAPI/Swagger)
- Data validation in other systems
- Schema registries (Confluent Schema Registry)
- Code generation in other languages
- Database schema creation
- Contract testing between services

## Troubleshooting

**Import Errors:**
- Use `generate_standalone_schemas.py` if you have import issues
- Make sure your Python path includes the module you're trying to import
- Check that all dependencies are installed

**Module Not Found:**
- Verify the module path is correct (use dots, not slashes)
- Ensure you're running from the correct directory
- Check that `__init__.py` files exist in your package directories
