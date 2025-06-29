# Be sure to restart your server when you modify this file.
#
# This file contains migration options to ease your Rails upgrade.
#
# Once upgraded flip defaults one by one to migrate to the new default.
#
# Read the Guide for Upgrading Ruby on Rails for more info on each option.

# FROM Rails 4.2 to Rails 5.0

# Enable per-form CSRF tokens. Previous versions had false.
Rails.application.config.action_controller.per_form_csrf_tokens = false

# Enable origin-checking CSRF mitigation. Previous versions had false.
Rails.application.config.action_controller.forgery_protection_origin_check = false

# Make Ruby 2.4 preserve the timezone of the receiver when calling `to_time`.
# Previous versions had false.
ActiveSupport.to_time_preserves_timezone = false

# Require `belongs_to` associations by default. Previous versions had false.
Rails.application.config.active_record.belongs_to_required_by_default = false


# FROM Rails 5.0 to Rails 5.2

# Make Active Record use stable #cache_key alongside new #cache_version method.
# This is needed for recyclable cache keys.
# Rails.application.config.active_record.cache_versioning = true

# Use AES-256-GCM authenticated encryption for encrypted cookies.
# Also, embed cookie expiry in signed or encrypted cookies for increased security.
#
# This option is not backwards compatible with earlier Rails versions.
# It's best enabled when your entire app is migrated and stable on 5.2.
#
# Existing cookies will be converted on read then written with the new scheme.
# Rails.application.config.action_dispatch.use_authenticated_cookie_encryption = true

# Use AES-256-GCM authenticated encryption as default cipher for encrypting messages
# instead of AES-256-CBC, when use_authenticated_message_encryption is set to true.
# Rails.application.config.active_support.use_authenticated_message_encryption = true

# Add default protection from forgery to ActionController::Base instead of in
# ApplicationController.
# Rails.application.config.action_controller.default_protect_from_forgery = true

# Store boolean values that are in sqlite3 databases as 1 and 0 instead of 't' and
# 'f' after migrating old data.
# Rails.application.config.active_record.sqlite3.represent_boolean_as_integer = true

# Use SHA-1 instead of MD5 to generate non-sensitive digests, such as the ETag header.
# Rails.application.config.active_support.use_sha1_digests = true

# Make `form_with` generate id attributes for any generated HTML tags.
# Rails.application.config.action_view.form_with_generates_ids = true
