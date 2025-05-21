FROM ruby:2.6

# Install Node.js LTS
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
RUN . "$HOME/.nvm/nvm.sh"

# Install Ruby bundler
RUN gem install bundler -v 2.4.22 # TODO: once we have a newer version of rails, remove version specifier

# Install mysql
RUN apt update
RUN apt install -y mariadb-server # Apt cannot find mysql-server ¯\_(ツ)_/¯ 
