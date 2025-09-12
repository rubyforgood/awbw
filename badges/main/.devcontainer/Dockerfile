FROM ruby:3.3.8-bookworm

# Install Ruby bundler
RUN gem install bundler -v 2.4.22 # TODO: once we have a newer version of rails, remove version specifier

# Install mysql
RUN apt update -qq && apt install -y mariadb-server
