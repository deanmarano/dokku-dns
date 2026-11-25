# Namecheap DNS Provider

This provider manages DNS for domains registered with Namecheap that use
Namecheap's own DNS ("BasicDNS" or "PremiumDNS").

## Setup

1. Enable API access at <https://ap.www.namecheap.com/settings/tools/apiaccess/>.
   Namecheap only grants API access to accounts that meet its eligibility
   requirements.
2. Whitelist this server's public IP on the same page.
3. Configure Dokku:

```shell
dokku config:set --global \
  NAMECHEAP_API_USER=your_username \
  NAMECHEAP_API_KEY=your_api_key

# optional: the whitelisted IP, if it can't be detected automatically
dokku config:set --global NAMECHEAP_CLIENT_IP=203.0.113.10

dokku dns:providers:verify namecheap
```

## How record changes work

Namecheap has no per-record API: `setHosts` replaces every record in a domain.
To change one record the provider reads all of them, changes that one, and
writes the full set back. To avoid ever deleting records by accident it:

- refuses to write if any existing record can't be parsed,
- refuses to manage domains that aren't using Namecheap DNS,
- sends every value URL-encoded in a POST body, so SPF and DKIM values
  survive unchanged,
- keeps MX preferences and the domain's mail setting (`EmailType`).

Changes made in the Namecheap dashboard between the read and the write can
still be overwritten, so avoid editing the same domain in both places at once.
