FROM ruby:3.3.8-slim AS base

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
RUN gem install bundler -v 2.5.22


FROM base AS assets

# Install basic Linux packages
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  nodejs \
  yarn \
  imagemagick \
  libvips \
  tzdata \
  libxml2-dev \
  libxslt1-dev \
  libffi-dev \
  libreadline-dev \
  libssl-dev \
  zlib1g-dev

# Copy app code and install dependencies
COPY . .

RUN bundle install --without development test

# These envs are used in the rails application. While they are entirely 
# unrelated to the docker build process, they are required for the app to run.
# Without these build args the asset precompilation will fail.

# Precompile assets (if applicable)
RUN SECRET_KEY_BASE=1 bundle exec rake assets:precompile


FROM base AS server

RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    imagemagick \
    libvips \
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

# Copy app code and install dependencies
COPY . .

# Expose port (default Rails)
EXPOSE 3000

# Start the server (customize to your app server if needed)
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
