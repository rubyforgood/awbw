module TurboFlashHelper
  # Renders a turbo_stream.replace if flash messages are present.
  # Example usage:
  #   <%= turbo_frame_tag "bookmark_button" do %>
  #     ...
  #     <%= turbo_flash %>
  #   <% end %>
  #
  def turbo_flash
    return unless flash.any?

    turbo_stream.replace("flash_now", partial: "shared/flash_messages")
  end
end
