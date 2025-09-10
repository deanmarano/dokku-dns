# Template DNS Provider

This is a template for creating new DNS providers for the Dokku DNS plugin.

## Creating a New Provider

1. **Copy the template:**
   ```bash
   cp -r providers/template providers/YOUR_PROVIDER_NAME
   cd providers/YOUR_PROVIDER_NAME
   ```

2. **Update the configuration:**
   Edit `config.sh` and set:
   - `PROVIDER_NAME` - Your provider's name (lowercase, no spaces)
   - `PROVIDER_DISPLAY_NAME` - Human-readable name
   - `PROVIDER_DOCS_URL` - Link to your provider's API documentation
   - `PROVIDER_REQUIRED_ENV_VARS` - Required environment variables
   - `PROVIDER_OPTIONAL_ENV_VARS` - Optional environment variables

3. **Implement the functions:**
   Edit `provider.sh` and implement the 6 required functions:
   - `provider_validate_credentials()` - Check if credentials work
   - `provider_list_zones()` - List available DNS zones
   - `provider_get_zone_id()` - Get zone identifier for a domain
   - `provider_get_record()` - Get current DNS record value
   - `provider_create_record()` - Create/update a DNS record
   - `provider_delete_record()` - Delete a DNS record

4. **Test your provider:**
   ```bash
   # Test credential validation
   PROVIDER_API_KEY=xxx ./provider.sh provider_validate_credentials
   
   # Test zone listing
   ./provider.sh provider_list_zones
   
   # Test record operations
   ./provider.sh provider_get_zone_id example.com
   ./provider.sh provider_create_record zone123 test.example.com A 192.168.1.100 300
   ```

5. **Register your provider:**
   ```bash
   echo "YOUR_PROVIDER_NAME" >> ../available
   ```

## Implementation Tips

### API Client Libraries
- Use `curl` for HTTP APIs (most portable)
- Use `jq` for JSON parsing (widely available)
- Keep dependencies minimal

### Error Handling
- Return 0 for success, 1 for failure
- Write errors to stderr: `echo "Error message" >&2`
- Write normal output to stdout: `echo "result"`

### Environment Variables
- Use consistent naming: `PROVIDER_API_KEY`, `PROVIDER_API_SECRET`
- Support both direct env vars and credential files
- Provide clear error messages for missing credentials

### Testing
- Test with invalid credentials
- Test with non-existent zones/records
- Test with various record types (A, CNAME, TXT)
- Test rate limiting behavior

## Example Providers

See these working implementations for reference:
- `providers/aws/` - AWS Route53
- `providers/cloudflare/` - Cloudflare (coming soon)
- `providers/digitalocean/` - DigitalOcean (coming soon)