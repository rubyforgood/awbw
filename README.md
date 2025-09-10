# awbw-portal

This project is the Leaders Dashboard for the A Windows Between Worlds Leader site. The Leaders site
offers a place for workshop leaders to provide input and information about workshops.

# Prerequisits

- Ruby 2.7+
- Rubygems

# Getting Started

## Using Codespaces

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/rubyforgood/awbw/tree/main?quickstart=1)

## Local development

### Install Bundler

Bundler is used as a Ruby package management software in this project. To install it use

    gem install bundler

Bundler installs dependencies from Gemfile.

### Install Dependencies

To install new dependencies, or update existing ones to new a new version found in the Gemfile.

    bundle install

### Local MySQL Server

A local MySQL server must be running and configured for this software to function. If you have Docker
installed, you can quickly start a container for development:

    docker run --name awbw_mysql -e MYSQL_ALLOW_EMPTY_PASSWORD=true -e MYSQL_DATABASE=awbw_development -p 3306:3306 -d mysql:latest -a

If you do not have Docker installed, or prefer to run the MySQL server some other way, the following information is required:

| Name | Value |
|-------|-------|
| Database | awbw_development |
| Username | root |
| Password | <ALLOW EMPTY PASSWORD>  |

### Database Migrations

To update to the latest schema version, use

    rake db:migrate

### Seed Data

The seed file will load a dump from production data and create a user and
admin you can use for local development:

- User
  - email: umberto.user@example.com
  - password: password
- Admin
  - email: amy.admin@example.com
  - password: password

**Note**: Why load up a production dump? Great question. There is no seed
file, and the utility (`lib/tasks/setup.rake`) to bootstrap development with
generated data does NOT work. So unless we wanted to stare at a blank screen, we
needed to repurpose this sanitized dump file to stand up dev.

### Starting the Development Server

To start the development server run:

    bin/rails server

One the application loads, it will be available at http://localhost:3000. The admin panel will be
available at http://localhost:3000/admin/cms

# Tests

## Running Tests

To run the full test suite:

```shell
bin/rspec
```

To run specific test types:

```shell
# Run only model specs
bin/rspec spec/models/

# Run only system specs (end-to-end tests)
bin/rspec spec/system/

# Run a specific test file
bin/rspec spec/models/workshop_spec.rb
```

## Testing Strategy

This legacy Rails application was recently upgraded from Rails 4.x and originally had no automated tests. We are starting to implement a comprehensive testing strategy using RSpec and FactoryBot.

### Test Structure

- **System Specs** (`spec/system/`): End-to-end browser-based tests using Capybara to verify happy paths of critical behavior
- **Model Specs** (`spec/models/`): Unit tests for ActiveRecord models, validations, associations, and business logic
- **Service Specs** (`spec/services/`): Tests for service objects and lower-level building blocks
- **Mailer Specs** (`spec/mailers/`): Email functionality tests for lower-level building blocks
- **Factory Definitions** (`spec/factories/`): Test data generators using FactoryBot

### Key Testing Focus Areas

- **System specs to verify happy paths of critical behavior**: User authentication flows, workshop creation and management, search functionality, report submission workflows
- **Model/mailer/service specs for verifying lower level building blocks**: Business logic validation, email delivery, authentication tokens, permission systems, and data relationships

### Test Configuration

The test suite uses:
- **RSpec Rails** for the testing framework
- **FactoryBot** for test data generation
- **Capybara** for browser automation in system specs
- **Shoulda Matchers** for model testing helpers
- **Devise Test Helpers** for authentication in tests

### Running Tests in Development

Ensure MySQL test database is running:
```shell
# Using Docker
docker run --name awbw_mysql_test -e MYSQL_ALLOW_EMPTY_PASSWORD=true -e MYSQL_DATABASE=awbw_test -p 3307:3306 -d mysql:latest

# Setup test database
RAILS_ENV=test rake db:create db:migrate
```

User Permissions
================

user = User.last
user.permissions << Permission.new(security_cat: "Children's Windows")

Using the CMS
==============
A given user can have 3 kind of permissions that belongs to a windows type
so "Adult Windows", "Children's Windows" or "Combined Adult and Children's Windows"
and it works with the user's curriculum, so if a user wants so "see" a particular
resource that has "Children's Windows" as windows type it should have that permission.
Using the CMS tool and admin user can add permissions to a given user in the user
section.
![Alt text](app/assets/images/awbw-user-perms-cms.png?raw=true "Permissions")

User Orphaned Reports
======================

When a user is deleted all their reports are assigned to the "orphaned reports user",
if you want to take a look to all the orphaned reports, you should login using these credentials:

user: orphaned_reports@awbw.org
pass: awbworphaned

Development flow
================

1) We have 2 branches on git: { *staging* - *production* },
we do branching from *production* so when you start a new ticket you should
create a new feature branch:

```git checkout production```

```git checkout -b feature/awbw-123-ticket-description```

2) You work and do stuff and push changes to the feature branch when you finish your
work you should create a new PR and leave it as open.

3) Then you should merge your branch to staging

```git checkout staging```

```git merge feature/awbw-123-ticket-description && git push```

4) Then your changes will be in the staging env in the next deploy.
This ticket will be tested and approved by QA.

5) Once the ticket is approved it will be merged to production
by clickling in *merge* button on Github, then changes will be live in the next deploy to production env:
This last step should be done by the deploy admin (Gastón).

When the ticket is not approved:
================================

If the ticket requires some changes to be approved, you should
work on the feature branch, update the PR and re-start the same flow
described above.
