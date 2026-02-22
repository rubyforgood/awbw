# Be sure to restart your server when you modify this file.

# Append port to cookie name so Conductor workspaces don't share sessions.
port_suffix = ENV["CONDUCTOR_PORT"] ? "_#{ENV['CONDUCTOR_PORT']}" : ""
Rails.application.config.session_store :cookie_store, key: "_awbw_session#{port_suffix}"
