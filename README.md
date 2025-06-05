# awbw-portal

This project is the Leaders Dashboard for the A Windows Between Worlds Leader site. The Leaders site
offers a place for workshop leaders to provide input and information about workshops.

# Prerequisits

- Ruby 2.7+
- Rubygems

# Getting Started

## Using Codespaces

As part of rubyforgood/awbw-dashboard#9, the development container configuration has been set up to be used in Codespaces. This means that there should be no set up needed, and one will only need to run the rails project via:
```shell
rails server
```

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

To run tests run:

```shell
bin/rspec
```

This will execute all the tests in the `spec/` directory and provide a summary of the results.

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
