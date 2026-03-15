FROM erlang:28.4.1 AS build
COPY --from=ghcr.io/gleam-lang/gleam:v1.14.0-erlang-alpine /bin/gleam /bin/gleam
COPY . /app/
RUN cd /app/server && gleam export erlang-shipment

FROM erlang:28.4.1-alpine
RUN \
  addgroup --system pastem && \
  adduser --system pastem -g pastem
USER pastem
COPY --from=build /app/server/build/erlang-shipment /app
WORKDIR /app
EXPOSE 8000
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
