module SearchEngineHideable
  extend ActiveSupport::Concern

  private

  # Tell compliant crawlers not to index this response. Sent as an HTTP header so
  # it also covers non-HTML responses (downloads, redirects) a <meta> tag can't
  # reach. Advisory only — the slug/ticket token remains the actual access gate.
  def noindex!
    response.set_header("X-Robots-Tag", "noindex, nofollow")
  end
end
