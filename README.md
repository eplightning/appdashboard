# Appdashboard

Appdashboard is an application created in order to help track the state (version, build date ...) of multiple applications running in different environments.

Applications and environments can be specified in configuration file statically, or they can be auto-discovered (currently only via HTTP).

Data for instances - application, environment pair - is fetched using providers (currently only HTTP is supported). Fetched data is then processed and relevant pieces of information are extracted - via JSONPath or templates.

This project is still WIP and heavily in development. Nevertheless, it's stable enough to be run in a non-production environment.

## Configuration

Bootstrap configuration is written in TOML language. Example configuration files are available in `examples` directory.

TODO: Add more examples

## Docker

The application is prepared to be run inside a container. Database is required in order to store snapshots (and more data in the future) - only PostgreSQL is supported at the moment.

Docker images are built and available on Dockerhub under `bslawianowski/appdashboard`

Below is an example of running it with Docker:

```
docker run \
  -e CONFIG_PATH=/etc/config.toml \
  -e "DATABASE_URL=ecto://postgres:postgres@localhost/appdashboard_dev" \
  -e "SECRET_KEY_BASE=$(mix phx.gen.secret)" \
  -v "$PWD/examples/config.toml:/etc/config.toml:ro" \
  bslawianowski/appdashboard:latest
```

## Development

To start your Phoenix server:

  * Setup the project with `mix setup`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
