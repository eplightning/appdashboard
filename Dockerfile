FROM elixir:1.11-alpine AS build

# install build dependencies
RUN apk add --no-cache build-base npm git python3 && \
    mkdir /app

WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV=prod

# install mix dependencies
COPY mix.exs mix.lock ./
COPY config config
RUN mix do deps.get, deps.compile

# build assets
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error

COPY priv priv
COPY assets assets
RUN npm run --prefix ./assets deploy && \
    mix phx.digest

# compile and build release
COPY lib lib

RUN mix do compile, release

ADD scripts/run_application.sh /app/_build/prod/rel/appdashboard/bin/
RUN chmod +x /app/_build/prod/rel/appdashboard/bin/run_application.sh

# prepare release image
FROM alpine:3.13

RUN apk add --no-cache openssl ncurses-libs inotify-tools && \
    mkdir /app && chown nobody:nobody /app

WORKDIR /app
USER nobody:nobody
ENV HOME=/app

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/appdashboard ./

CMD ["bin/run_application.sh"]
