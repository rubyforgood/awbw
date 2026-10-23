module YoutubeHelper
  BACKGROUND_PLAYER_PARAMS = { autoplay: 1, mute: 1, loop: 1, controls: 0, playsinline: 1, disablekb: 1, rel: 0 }.freeze

  # js_api lets the page send the player commands (e.g. pause) via postMessage.
  def youtube_embed_url(url, js_api: false)
    video_id = youtube_video_id(url)
    return unless video_id

    embed_url = "https://www.youtube.com/embed/#{video_id}"
    js_api ? "#{embed_url}?enablejsapi=1" : embed_url
  end

  # Muted autoplay is the only autoplay browsers allow; loop needs the video listed as its own playlist.
  def youtube_background_embed_url(url)
    video_id = youtube_video_id(url)
    return unless video_id

    "https://www.youtube.com/embed/#{ERB::Util.url_encode(video_id)}?#{BACKGROUND_PLAYER_PARAMS.merge(playlist: video_id).to_query}"
  end

  def youtube_video_id(url)
    return if url.blank?

    uri = URI.parse(url) rescue nil
    return unless uri

    video_id = if uri.host&.include?("youtu.be")
      uri.path.delete_prefix("/")
    elsif uri.query
      Rack::Utils.parse_query(uri.query)["v"]
    end
    video_id.presence
  end
end
