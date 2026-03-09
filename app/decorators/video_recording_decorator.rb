class VideoRecordingDecorator < ApplicationDecorator
  delegate_all

  def detail(length: nil)
    text = rhino_body&.to_plain_text
    length ? text&.truncate(length) : text
  end
end
