FROM ruby:2.7.8-buster

# Install basic Linux packages
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  libpq-dev \
  nodejs \
  yarn \
  git \
  curl \
  imagemagick \
  libvips \
  tzdata \
  libxml2-dev \
  libxslt1-dev \
  libffi-dev \
  libreadline-dev \
  libssl-dev \
  zlib1g-dev \
  libsqlite3-dev \
  sqlite3

# Set working directory
WORKDIR /app

# Set environment variables
ENV RAILS_ENV=production \
    RACK_ENV=production \
    BUNDLE_PATH=/gems \
    BUNDLE_BIN=/gems/bin \
    PATH="/gems/bin:$PATH"

# Install bundler
RUN gem install bundler -v 2.4.12

# Copy app code and install dependencies
COPY . .

RUN bundle install --without development test

# These envs are used in the rails application. While they are entirely 
# unrelated to the docker build process, they are required for the app to run.
# Without these build args the asset precompilation will fail.
ARG SECRET_KEY_BASE
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG AWS_REGION
ARG AWS_S3_BUCKET
ARG SMTP_USERNAME
ARG SMTP_PASSWORD
ARG SMTP_SERVER
ARG SMTP_PORT

# Precompile assets (if applicable)
RUN bundle exec rake assets:precompile

# Expose port (default Rails)
EXPOSE 3000

# Start the server (customize to your app server if needed)
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]