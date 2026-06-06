# Be sure to restart your server when you modify this file.

# Append port to cookie name so parallel workspaces don't share sessions.
# Under Conductor, WORKSPACE_PORT is derived from CONDUCTOR_PORT by the
# bin/conductor-* scripts.
workspace_port = ENV["WORKSPACE_PORT"]
port_suffix = workspace_port ? "_#{workspace_port}" : ""
Rails.application.config.session_store :cookie_store, key: "_awbw_session#{port_suffix}"
