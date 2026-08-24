# Build stage.
#
# The build context is the pub *workspace* root — the `draw_together_serverpod`
# directory holding this server, the client, and the shared pubspec.lock — not
# this server package. Both packages declare `resolution: workspace`, so pub
# refuses to resolve either one without the root pubspec.yaml above it, and the
# shared lockfile is what pins the versions the server compiles against.
# Resolving fresh instead picks up relic 1.2.0, which collides with the `Cache`
# symbol in serverpod 3.3.1 and fails the AOT compile.
#
# The SDK must be at least 3.10.0, as pubspec.lock requires.
FROM dart:3.10.1 AS build
WORKDIR /app

# The pubspecs are copied on their own first so the dependency layer stays cached
# across source-only edits.
COPY pubspec.yaml pubspec.lock ./
COPY draw_together_serverpod_client/pubspec.yaml draw_together_serverpod_client/
COPY draw_together_serverpod_server/pubspec.yaml draw_together_serverpod_server/
RUN dart pub get

COPY . .
RUN dart pub get --offline

WORKDIR /app/draw_together_serverpod_server
RUN dart compile exe bin/main.dart -o bin/server

# Final stage
FROM alpine:latest

# Environment variables
ENV runmode=production
ENV serverid=default
ENV logging=normal
ENV role=monolith

# Copy runtime dependencies
COPY --from=build /runtime/ /

WORKDIR /app

# Copy compiled server executable
COPY --from=build /app/draw_together_serverpod_server/bin/server server

# Copy configuration files and resources
COPY --from=build /app/draw_together_serverpod_server/config/ config/
COPY --from=build /app/draw_together_serverpod_server/web/ web/
COPY --from=build /app/draw_together_serverpod_server/migrations/ migrations/

# This file is required to enable the endpoint log filter in Insights.
COPY --from=build /app/draw_together_serverpod_server/lib/src/generated/protocol.yaml lib/src/generated/protocol.yaml

# Expose ports
EXPOSE 8080
EXPOSE 8081
EXPOSE 8082

# Define the entrypoint command
ENTRYPOINT ./server --mode=$runmode --server-id=$serverid --logging=$logging --role=$role
