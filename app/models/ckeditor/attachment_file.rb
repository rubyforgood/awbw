class Ckeditor::AttachmentFile < ApplicationRecord # Ckeditor::Asset
  has_one_attached :data

  def url_thumb
    @url_thumb ||= nil # Ckeditor::Utils.filethumb(filename)
  end
end
