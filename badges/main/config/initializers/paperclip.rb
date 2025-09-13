Paperclip::Attachment.default_options[:path] = ":rails_root/public:url"
Paperclip::Attachment.default_options[:url]  = "/system/:class/:attachment/:id_partition/:style/:filename"
Paperclip::Attachment.default_options[:default_url] = "/images/missing.png"