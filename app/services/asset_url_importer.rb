# frozen_string_literal: true

require "open-uri"

# Creates an Asset from a remote file URL: downloads the bytes and attaches them
# to ActiveStorage on the given owner. The URL is only the source — the file is
# stored like any uploaded asset, so the subclass's content-type validation
# still applies. Prior art: the removed resources:migrate_pdfs rake task used the
# same open-uri → attach flow.
class AssetUrlImporter
  Error = Class.new(StandardError)

  DEFAULT_TYPE = "GalleryAsset"
  READ_TIMEOUT = 30

  def initialize(url:, owner:, type: DEFAULT_TYPE, title: nil)
    @url = url.to_s.strip
    @owner = owner
    @type = type
    @title = title
  end

  def call
    io = open_remote
    asset = @owner.assets.build(type: @type, title: @title.presence)
    asset.file.attach(io: io, filename: filename, content_type: io.content_type)
    asset.save!
    asset
  ensure
    io.close if io.respond_to?(:close)
  end

  private

  def open_remote
    uri = URI.parse(@url)
    raise Error, "not an http(s) url: #{@url.inspect}" unless uri.is_a?(URI::HTTP)

    uri.open(read_timeout: READ_TIMEOUT, ssl_verify_mode: OpenSSL::SSL::VERIFY_PEER)
  rescue OpenURI::HTTPError, SocketError, OpenSSL::SSL::SSLError,
         Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    raise Error, "could not download #{@url.inspect}: #{e.class} #{e.message}"
  end

  def filename
    File.basename(URI.parse(@url).path.presence || "").presence || "asset"
  end
end
