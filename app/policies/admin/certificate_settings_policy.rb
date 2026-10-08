module Admin
  # The certificate-of-completion settings page manages global, admin-uploaded
  # certificate artwork (frame overrides and the signature strips). Same bar as
  # the rest of the admin namespace — super-user only.
  class CertificateSettingsPolicy < ApplicationPolicy
    def show?
      admin?
    end

    def update?
      admin?
    end
  end
end
