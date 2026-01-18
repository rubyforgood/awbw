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
end
