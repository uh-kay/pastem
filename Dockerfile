# Build
FROM erlang:28.4.1 AS build
COPY --from=ghcr.io/gleam-lang/gleam:v1.14.0-erlang-alpine /bin/gleam /bin/gleam
COPY . /app/
RUN cd /app/server && gleam export erlang-shipment

# Run
FROM erlang:28.4.1-alpine
RUN apk add --no-cache caddy

COPY --from=build /app/server/build/erlang-shipment /app
WORKDIR /app

RUN chmod +x /app/entrypoint.sh

COPY Caddyfile /etc/caddy/Caddyfile
COPY start.sh /start.sh
RUN chmod +x /start.sh

ENV CADDY_PORT=8080
ENV PORT=4000
CMD ["/start.sh"]
