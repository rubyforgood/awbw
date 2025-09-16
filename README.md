# awbw-portal
![Coverage](https://rubyforgood.github.io/awbw/badges/main/coverage_badge.svg)

This project is the Leaders Dashboard for the A Windows Between Worlds Leader site. The Leaders site
offers a place for workshop leaders to provide input and information about workshops.

## Architecture Overview

This is a Rails 6.1 application built with:

- **Authentication**: Devise for user authentication with API token support
- **Admin Interface**: RailsAdmin for content management
- **Frontend**: Bootstrap with SASS for styling
- **Database**: MySQL with ActiveRecord ORM
- **File Uploads**: Paperclip with AWS S3 storage
- **Email**: ActionMailer for transactional emails (*TODO* Need to configure smtp creds)
- **API**: JSON API with JWT authentication

## Key Features

- **Workshop Management**: Create, edit, and manage workshops
- **User Permissions**: Role-based access control with window type permissions
- **Reporting System**: Monthly and annual reporting workflows
- **Resource Library**: File uploads and document management
- **API Access**: RESTful API for external integrations
- **Admin CMS**: RailsAdmin interface for content management

## Getting Started

For detailed setup and development instructions, please see our [CONTRIBUTING.md](CONTRIBUTING.md) guide.

## User Permissions System

- **Adult Windows**: Access to adult workshop resources
- **Children's Windows**: Access to children's workshop resources
- **Combined Adult and Children's Windows**: Access to both resource types

Permissions are managed through the RailsAdmin CMS interface, where administrators can assign specific window type permissions to users based on their curriculum needs.

## Orphaned Reports

When users are deleted from the system, their reports are automatically assigned to a special "orphaned reports user" account. To access these reports:

- Email: <orphaned_reports@awbw.org>
