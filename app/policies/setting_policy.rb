# Super-admins only, which is ApplicationPolicy's default rule. Declared so the
# settings page has an explicit policy rather than relying on inference.
class SettingPolicy < ApplicationPolicy
end
