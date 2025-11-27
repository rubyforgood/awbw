# awbw-portal
![Coverage](https://rubyforgood.github.io/awbw/badges/main/coverage_badge.svg)

This project is the Facilitator Portal for [A Windows Between Worlds](https://www.awbw.org). The Facilitator Portal
offers a place for workshop leaders to find information about Workshops and Resources, 
be informed of CommunityNews, Stories, and Events, and as the project evolves -- to connect with one another.

## Architecture Overview

This is a Rails 8.1.0 application built with:

- **Authentication**: Devise for user authentication with API token support
- **Frontend**: Tailwind for styling
- **Database**: MySQL with ActiveRecord ORM
- **File Uploads**: ActiveStorage with DigitalOcean Spaces storage
- **Email**: ActionMailer for transactional emails (*TODO* Need to configure smtp creds)
- **API**: JSON API with JWT authentication

## Key Features

- **Workshop Management**: Create, edit, and manage workshops
- **Resource Library**: File uploads and document management
- **Event Registration**: Search and register for events
- **Stories Library**: Submit and view articles (stories) about workshops and facilitators
- **Facilitator and Organization Profiles**: View facilitators and organizations at a glance
- **Reporting System**: Monthly and annual reporting workflows
- **API Access**: RESTful API for external integrations

## Getting Started

For detailed setup and development instructions, please see our [CONTRIBUTING.md](CONTRIBUTING.md) guide.

## Orphaned Reports

When users are deleted from the system, their reports are automatically assigned to a special 
"orphaned reports user" account. To access these reports:
- Email: <orphaned_reports@awbw.org>
