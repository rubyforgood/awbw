module ConfirmModalHelpers
  # Drop-in replacements for Capybara's accept_confirm / dismiss_confirm now that
  # confirmations render in the styled in-page modal (shared/_confirm_modal)
  # instead of the browser's native confirm() dialog.
  #
  # Pass a block that triggers the confirmation (the modal opens after it runs),
  # or call with no block if the triggering action already happened. An optional
  # text argument (String or Regexp) asserts the modal's message.
  #
  # Call these at the top level, not nested inside another `within` block, so the
  # modal — rendered at the end of <body> — is in scope.
  def accept_confirm_modal(text = nil)
    yield if block_given?
    within_confirm_modal(text) { click_button "Confirm" }
  end

  def dismiss_confirm_modal(text = nil)
    yield if block_given?
    within_confirm_modal(text) { click_button "Cancel" }
  end

  def within_confirm_modal(text)
    within "[data-controller='confirm-modal']" do
      expect(page).to have_text(text) if text
      yield
    end
  end
end

RSpec.configure do |config|
  config.include ConfirmModalHelpers, type: :system
end
