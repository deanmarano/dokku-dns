# DNS Provider Interface Specification

This document defines the minimal interface that every DNS provider must implement to be compatible with the Dokku DNS plugin.

## Required Functions

Every provider must implement these exact function signatures:

### Core Functions

#### `provider_validate_credentials()`
- **Purpose**: Check if provider credentials are properly configured
- **Returns**: 0 if valid, 1 if invalid
- **Output**: Error message on stderr if invalid

#### `provider_list_zones()`
- **Purpose**: List all DNS zones available to the configured account
- **Returns**: 0 on success, 1 on failure
- **Output**: One zone name per line on stdout (e.g., "example.com")

#### `provider_get_zone_id(zone_name)`
- **Purpose**: Get the provider-specific zone identifier
- **Parameters**: `zone_name` - The DNS zone name (e.g., "example.com")
- **Returns**: 0 if found, 1 if not found
- **Output**: Zone ID on stdout (e.g., "Z123456789" for AWS, "abc123" for Cloudflare)

#### `provider_get_record(zone_id, record_name, record_type)`
- **Purpose**: Get current DNS record value
- **Parameters**: 
  - `zone_id` - Provider zone identifier
  - `record_name` - Full record name (e.g., "api.example.com")
  - `record_type` - Record type (e.g., "A", "CNAME")
- **Returns**: 0 if record exists, 1 if not found
- **Output**: Record value on stdout (e.g., "192.168.1.100")

#### `provider_create_record(zone_id, record_name, record_type, record_value, ttl)`
- **Purpose**: Create or update a DNS record
- **Parameters**:
  - `zone_id` - Provider zone identifier
  - `record_name` - Full record name (e.g., "api.example.com")
  - `record_type` - Record type (e.g., "A", "CNAME")
  - `record_value` - Record value (e.g., "192.168.1.100")
  - `ttl` - TTL in seconds (e.g., "300")
- **Returns**: 0 on success, 1 on failure
- **Output**: Success/error message on stdout/stderr

#### `provider_delete_record(zone_id, record_name, record_type)`
- **Purpose**: Delete a DNS record
- **Parameters**:
  - `zone_id` - Provider zone identifier
  - `record_name` - Full record name (e.g., "api.example.com")
  - `record_type` - Record type (e.g., "A", "CNAME")
- **Returns**: 0 on success, 1 on failure
- **Output**: Success/error message on stdout/stderr

### Optional Functions

#### `provider_setup_env()`
- **Purpose**: Perform any provider-specific environment setup
- **Returns**: 0 on success, 1 on failure
- **Default**: No-op (return 0)

#### `provider_batch_create_records(zone_id, records_file)`
- **Purpose**: Create multiple records in one operation (optimization)
- **Parameters**:
  - `zone_id` - Provider zone identifier
  - `records_file` - File with one record per line: "name type value ttl"
- **Returns**: 0 on success, 1 on failure
- **Default**: Fallback to individual create_record calls

## Provider Structure

Each provider must be in its own directory: `providers/PROVIDER_NAME/`

### Required Files

#### `providers/PROVIDER_NAME/provider.sh`
Main provider implementation with all required functions.

#### `providers/PROVIDER_NAME/config.sh`
Provider configuration and metadata:
```bash
PROVIDER_NAME="aws"
PROVIDER_DISPLAY_NAME="AWS Route53"
PROVIDER_DOCS_URL="https://docs.aws.amazon.com/route53/"
PROVIDER_REQUIRED_ENV_VARS="AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY"
PROVIDER_OPTIONAL_ENV_VARS="AWS_DEFAULT_REGION"
```

### Optional Files

#### `providers/PROVIDER_NAME/install.sh`
Provider-specific installation instructions or dependency checks.

#### `providers/PROVIDER_NAME/README.md`
Provider-specific documentation and setup instructions.

## Function Naming Convention

All provider functions must use this exact naming pattern:
- `provider_function_name()` - Generic interface function
- Internal functions can use `_provider_internal_function()` with leading underscore

## Error Handling

- Return 0 for success, non-zero for failure
- Write error messages to stderr
- Write normal output to stdout
- Use consistent error messages across providers

## Testing

Each provider must include:
- Unit tests for each function
- Integration tests with mock API responses
- Credential validation tests

## Example Implementation

See `providers/aws/` for a reference implementation of this interface.

## Adding a New Provider

1. Copy `providers/template/` to `providers/PROVIDER_NAME/`
2. Implement the 6 required functions in `provider.sh`
3. Update `config.sh` with provider metadata
4. Test with mock provider validation
5. Add to `providers/available` list