FROM ruby:2.6 AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  software-properties-common \
  && apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8 \
  && add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirrors.coreix.net/mariadb/repo/10.1/ubuntu xenial main' \
  && (curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -) \
  && (echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list) \
  && (curl -sL https://deb.nodesource.com/setup_12.x | bash -) \
  && rm -rf /var/lib/apt/lists/*

# Install main dependencies
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  build-essential  \
  netcat \
  curl \
  libmariadb-dev \
  libcap2-bin \
  nano \
  nodejs

RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/ruby

# Configure 'postal' to work everywhere (when the binary exists
# later in this process)
ENV PATH="/opt/postal/app/bin:${PATH}"

# Setup an application
RUN useradd -r -d /opt/postal -m -s /bin/bash -u 999 postal
USER postal
RUN mkdir -p /opt/postal/app /opt/postal/config
WORKDIR /opt/postal/app

# Install bundler
RUN gem install bundler -v 2.1.4 --no-doc

# Install the latest and active gem dependencies and re-run
# the appropriate commands to handle installs.
COPY Gemfile Gemfile.lock ./
RUN bundle install -j 4

# Copy the application (and set permissions)
COPY ./docker/wait-for.sh /docker-entrypoint.sh
COPY --chown=postal . .

# Export the version
ARG VERSION=unspecified
RUN echo $VERSION > VERSION

# Set the path to the config
ENV POSTAL_CONFIG_ROOT=/config

# Set the CMD
ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD ["postal"]

# ci target - use --target=ci to skip asset compilation
FROM base AS ci

# prod target - default if no --target option is given
FROM base AS prod

RUN POSTAL_SKIP_CONFIG_CHECK=1 RAILS_GROUPS=assets bundle exec rake assets:precompile
RUN touch /opt/postal/app/public/assets/.prebuilt
