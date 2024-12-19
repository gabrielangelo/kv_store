FROM hexpm/elixir:1.16.0-erlang-26.2.1-debian-bullseye-20231009

RUN apt-get update && \
    apt-get install -y git build-essential && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod \
    SECRET_KEY_BASE=xJ4iHg5B5tZiyTRkHmqpBcGAM9p2PJi8LdsybeI6ZrkRYC9K6jzgHEDtU03V+tEn \
    PHX_HOST=localhost \
    PORT=4444

WORKDIR /app
COPY . .

RUN mix local.hex --force && \
    mix local.rebar --force

RUN mix deps.get --only prod && \
    mix deps.compile

RUN mix compile

RUN mix phx.digest

EXPOSE 4444

CMD ["mix", "phx.server"]