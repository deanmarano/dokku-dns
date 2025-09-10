# Mock DNS Provider

This is a mock DNS provider used for testing the provider abstraction system. It simulates DNS operations without making actual network calls.

## Purpose

- Test the provider interface implementation
- Demonstrate how easy it is to create a new provider
- Provide a working example for development and testing

## Usage

```bash
# Set the required API key (any non-empty value except "invalid")
export MOCK_API_KEY="test-key"

# Load the provider
source providers/mock/provider.sh

# Test the functions
provider_validate_credentials
provider_list_zones
provider_get_zone_id "example.com"
provider_create_record "zone123456" "test.example.com" "A" "192.168.1.200" "300"
provider_get_record "zone123456" "test.example.com" "A"
provider_delete_record "zone123456" "test.example.com" "A"
```

## Mock Data

The provider includes pre-configured test data:

### Zones
- `example.com` → `zone123456`
- `test.org` → `zone789012`
- `demo.net` → `zone345678`

### Records
- `www.example.com` (A) → `192.168.1.100` (TTL: 300)
- `api.example.com` (A) → `192.168.1.101` (TTL: 300)
- `test.org` (A) → `10.0.0.50` (TTL: 600)

## Testing Provider Abstraction

This mock provider proves that:
1. The minimal provider interface works
2. Any provider can be swapped in/out easily
3. The adapter layer is provider-agnostic
4. New providers are simple to implement

## Configuration

- **MOCK_API_KEY** (required): Any non-empty string except "invalid"
- **MOCK_API_ENDPOINT** (optional): Defaults to `https://api.mock-dns.com`