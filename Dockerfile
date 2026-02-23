FROM ruby:4.0.1-slim AS base

# Set working directory
WORKDIR /app

# Set environment variables
ENV RAILS_ENV=production \
    RACK_ENV=production \
    BUNDLE_PATH=/gems \
    BUNDLE_WITHOUT="development test" \
    BUNDLE_BIN=/gems/bin \
    PATH="/gems/bin:$PATH"

# Install bundler
RUN gem install bundler -v 4.0.4


FROM base AS assets

# Install basic Linux packages
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  nodejs \
  libvips \
  poppler-utils \
  tzdata \
  libxml2-dev \
  libxslt1-dev \
  libffi-dev \
  libreadline-dev \
  libssl-dev \
  libyaml-dev \
  nodejs \
  npm \
  s3cmd \
  zlib1g-dev

# Copy app code and install dependencies
COPY . .

RUN npm ci
RUN bundle config set without 'development test' && bundle install

# These envs are used in the rails application. While they are entirely 
# unrelated to the docker build process, they are required for the app to run.
# Without these build args the asset precompilation will fail.

# Precompile assets (if applicable)
RUN SECRET_KEY_BASE=1 \
    SMTP_PASSWORD=dummy \
    bundle exec rake assets:precompile

# Sync precompiled assets to DigitalOcean Spaces CDN (optional).
# Pass --build-arg DO_SPACES_KEY=... etc. to enable.
ARG DO_SPACES_KEY
ARG DO_SPACES_SECRET
ARG DO_SPACES_REGION
ARG DO_SPACES_BUCKET_ASSETS
RUN if [ -n "$DO_SPACES_KEY" ]; then \
      s3cmd --access_key="$DO_SPACES_KEY" \
            --secret_key="$DO_SPACES_SECRET" \
            --host="${DO_SPACES_REGION}.digitaloceanspaces.com" \
            --host-bucket="%(bucket)s.${DO_SPACES_REGION}.digitaloceanspaces.com" \
            --region="$DO_SPACES_REGION" \
            --no-mime-magic \
            --acl-public \
            --add-header="Cache-Control:public, immutable, max-age=31536000" \
            sync public/assets/ "s3://${DO_SPACES_BUCKET_ASSETS}/assets/" && \
      s3cmd --access_key="$DO_SPACES_KEY" \
            --secret_key="$DO_SPACES_SECRET" \
            --host="${DO_SPACES_REGION}.digitaloceanspaces.com" \
            --host-bucket="%(bucket)s.${DO_SPACES_REGION}.digitaloceanspaces.com" \
            --region="$DO_SPACES_REGION" \
            --no-mime-magic \
            --acl-public \
            --add-header="Cache-Control:public, immutable, max-age=31536000" \
            sync public/vite/ "s3://${DO_SPACES_BUCKET_ASSETS}/vite/"; \
    fi

FROM base AS server

RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    libvips \
    poppler-utils \
    tzdata \
    libxml2 \
    libxslt1.1 \
    libffi8 \
    libreadline8 \
    libssl3 \
    zlib1g \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*


# Set working directory
WORKDIR /app

COPY --from=assets /gems /gems
COPY --from=assets /app/public/assets /app/public/assets
COPY --from=assets /app/public/vite /app/public/vite

# Copy app code
COPY . .

# Expose port (default Rails)
EXPOSE 3000

# Start the server (customize to your app server if needed)
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
