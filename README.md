# awbw-portal
![Coverage](https://rubyforgood.github.io/awbw/badges/main/coverage_badge.svg)

This project is the Leaders Dashboard for the A Windows Between Worlds Leader site. The Leaders site
offers a place for workshop leaders to provide input and information about workshops.

## Architecture Overview

This is a Rails 6.1 application built with:

- **Authentication**: Devise for user authentication with API token support
- **Frontend**: Tailwind for styling
- **Database**: MySQL with ActiveRecord ORM
- **File Uploads**: ActiveStorage with AWS S3 storage
- **Email**: ActionMailer for transactional emails (*TODO* Need to configure smtp creds)
- **API**: JSON API with JWT authentication

## Key Features

- **Facilitator and Organization Profiles**: View facilitators and organizations at a glance
- **Workshop Management**: Create, edit, and manage workshops
- **Reporting System**: Monthly and annual reporting workflows
- **Resource Library**: File uploads and document management
- **API Access**: RESTful API for external integrations

## Getting Started

For detailed setup and development instructions, please see our [CONTRIBUTING.md](CONTRIBUTING.md) guide.

## Orphaned Reports

When users are deleted from the system, their reports are automatically assigned to a special "orphaned reports user" account. To access these reports:

- Email: <orphaned_reports@awbw.org>
