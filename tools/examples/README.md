# Tendance Examples

This directory contains example scripts demonstrating how to use the Tendance Stack Exchange Content Analyzer.

## Stack Overflow Client Demo

**File**: `so_client_demo.py`

Demonstrates the core functionality of the Stack Overflow API client:

- ✅ Basic question retrieval with filters
- 🔍 Search functionality for specific topics  
- 📄 Pagination through large result sets
- 📊 Statistics generation
- 💾 Saving and loading questions to/from JSON files
- 💬 Retrieving answers for specific questions

### Running the Demo

```bash
# From the tools directory
uv run python examples/so_client_demo.py
```

### API Key Setup (Recommended)

For higher rate limits (10,000 vs 300 requests/day), register for a Stack Exchange API key:

1. Visit https://stackapps.com/apps/oauth/register
2. Fill out the form (use placeholder URLs if needed)
3. Get your API key
4. Set it in the demo script or via environment variable:
   ```bash
   export STACKEXCHANGE_API_KEY="your_key_here"
   ```

## Future Examples

Additional examples will be added as new features are implemented:

- Web dashboard usage
- Configuration file examples
- Integration with external systems
- Batch processing scripts
