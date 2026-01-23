class DeviseMailerPreview < ActionMailer::Preview
  def reset_password_instructions
    user = User.first || FactoryBot.create(:user)
    DeviseMailer.reset_password_instructions(user, "fake-token").tap do |mail|
      # Force branding in preview context
      mail.instance_variable_set(
        :@organization_name,
        ENV.fetch("ORGANIZATION_NAME", "Our organization")
      )
    end
  end

  def confirmation_instructions
    user = User.where(confirmed_at: nil).first || FactoryBot.create(:user, confirmed_at: nil)
    DeviseMailer.confirmation_instructions(user, "fake-token").tap do |mail|
      # Force branding in preview context
      mail.instance_variable_set(
        :@organization_name,
        ENV.fetch("ORGANIZATION_NAME", "Our organization")
      )
    end
  end

  def unlock_instructions
    user = User.first || FactoryBot.create(:user, unlocked_at: nil)
    DeviseMailer.unlock_instructions(user, "fake-token").tap do |mail|
      # Force branding in preview context
      mail.instance_variable_set(
        :@organization_name,
        ENV.fetch("ORGANIZATION_NAME", "Our organization")
      )
    end
  end
end
