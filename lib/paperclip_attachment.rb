require 'paperclip'

module Paperclip
  class Attachment
    alias_method :orig_url, :url

    def url(*args)
      unless orig_url(*args).start_with? 'https'
        if orig_url(*args).start_with? 'http'
           orig_url(*args).gsub("http:", "https:")
        else
          orig_url(*args)
        end
      end

    end
  end
end
