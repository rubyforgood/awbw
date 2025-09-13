class Ckeditor::Picture < ApplicationRecord # Ckeditor::Asset
  has_one_attached :data

  def url_content
    url(:content)
  end

  def url(param)
    return super if actual_url.nil?

    if param == :content
      actual_url
    else
      actual_url.gsub("/original", "/thumb")
    end
  end
end
