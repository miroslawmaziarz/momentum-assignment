# syntax=docker/dockerfile:1
# check=error=true

# Two targets live here:
#
#   development — what `docker compose up` builds. Source is bind-mounted, gems live in a
#                 named volume, and the database is prepared on boot. This is the target a
#                 reviewer exercises.
#   (final)     — the production image Rails generates. Not used by compose; kept so the
#                 path to a real deployment is visible. Build with `docker build -t library .`
#
# Keep RUBY_VERSION in step with .ruby-version.
ARG RUBY_VERSION=3.4.7
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Packages needed at runtime. postgresql-client supplies pg_isready, used to wait for the
# database before booting.
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 postgresql-client && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV BUNDLE_PATH="/usr/local/bundle" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"


# Compiling native gem extensions (pg, bootsnap) needs a toolchain. Both the development
# target and the production build stage need it, so it is installed once here; production
# then discards this layer by copying only its results into the final image.
FROM base AS toolchain

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives


# Development target: used by docker-compose.yml. Keeps the toolchain, so adding a gem
# costs a `bundle install` in the running container rather than an image rebuild.
FROM toolchain AS development

ENV RAILS_ENV="development"

# Run as uid 1000 rather than root. The source is bind-mounted from the host, so anything
# the container writes there (db/schema.rb, generated files, logs) must not come back owned
# by root. 1000 is the first non-system uid on Linux and so the common single-user default.
RUN groupadd --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown rails:rails /rails

COPY --chown=rails:rails Gemfile Gemfile.lock .ruby-version ./
RUN chown -R rails:rails "${BUNDLE_PATH}"

USER 1000:1000
RUN bundle install

COPY --chown=rails:rails . .

ENTRYPOINT ["bin/docker-entrypoint"]
EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]


# Throw-away build stage to reduce size of the production image
FROM toolchain AS build

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development"

COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .

RUN bundle exec bootsnap precompile -j 1 app/ lib/


# Final production image
FROM base

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development"

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
