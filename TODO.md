# TODO

## Features

- Instance view
- Instance compare
- Instance change history
- Auto-snapshotting
- Allow use of EEx templates (fine for trusted config I suppose)
- Telemetry / Prometheus metrics

## Bugs, issues, enchancements

- Use Utils.Extractor for instance-level extractors
- Currently we don't detect changes to configuration that references files (i.e. tls_certificate_file). Probably should be solved at the config plane level...
- Error logs could use some improvement
- Probably should tweak supervisor values
- Don't launch full application (HTTP endpoint, config/data plane) when running migrations/other stuff in release.ex
- Upgrade to Gun 2.0 when released, remove cowlib dependency override
- Documentation
- Add some actual health checks in health probe plug

## Refactoring

- More tests
- Consider using Ecto for config structures
- Should probably use for comprehensions more
