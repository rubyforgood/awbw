# Staging toggle for the not-yet-launched public-profiles experience. When on,
# people and organizations become viewable by any signed-in user (never the
# anonymous public), and a person can edit their own profile. Off by default;
# set PROFILES_ENABLED in staging to preview what non-admin profile access feels
# like before it launches for real.
module Profiles
  def self.enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("PROFILES_ENABLED", false))
  end
end
