# OVHcloud DNS Provider

This provider manages DNS zones hosted by OVHcloud through its signed API.

## Setup

Create API credentials at <https://api.ovh.com/createToken/> for the API endpoint
that hosts your account. Grant the consumer key the following access rules:

- `GET /me`
- `GET /domain/zone/*`
- `POST /domain/zone/*`
- `PUT /domain/zone/*`
- `DELETE /domain/zone/*`

Then configure Dokku:

```shell
dokku config:set --global \
  OVH_APPLICATION_KEY=your_application_key \
  OVH_APPLICATION_SECRET=your_application_secret \
  OVH_CONSUMER_KEY=your_consumer_key
```

The default API endpoint is the European endpoint. For a different OVHcloud
region, set `OVH_API_ENDPOINT`, for example
`https://ca.api.ovh.com/1.0`.

Verify access and discover zones with:

```shell
dokku dns:providers:verify ovh
```

The provider uses `curl`, `jq`, and either `sha1sum` or `shasum`. OVHcloud DNS
changes are made live by refreshing the zone after each record mutation.
