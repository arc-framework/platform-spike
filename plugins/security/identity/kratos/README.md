Kratos configuration (local dev)

This directory is intentionally minimal in the platform-spike: Ory Kratos requires a careful configuration
for identity schemas, courier (email), and secrets. For the purposes of this spike we provide guidance
instead of a production-ready config.

How to add a local dev Kratos config:

1. Create a `kratos.yml` config file in this directory. Example minimal settings can be found in the Ory
   documentation: https://www.ory.sh/docs/kratos

2. Set the DSN for Kratos to point to the Postgres service. The `docker-compose.stack.yml` sets the
   DSN via environment variable using the project's `.env` values.

3. Run the Kratos migration tool before first run:

   docker run --rm -v $(pwd)/config/kratos:/etc/kratos oryd/kratos:v1.17.0 migrate sql -c /etc/kratos/kratos.yml

4. Customize identity schema JSON files and place them in `config/kratos/`.

Notes and caveats:
- Do NOT commit production secrets or courier credentials into this repo. Use environment variables
  or Docker secrets.
- The example DSN used by the compose file disables TLS (sslmode=disable) for local dev only.

