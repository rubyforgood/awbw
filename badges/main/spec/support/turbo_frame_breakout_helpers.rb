module TurboFrameBreakoutHelpers
  # Asserts that a link inside a lazy `*_results` turbo frame breaks out to the
  # top browsing context (`data-turbo-frame="_top"`). Without it, clicking the
  # link loads the destination *into* the results frame — which has no matching
  # frame — and Turbo swaps in the "Oopsie!" frame-missing box. `href_includes`
  # matches the destination path (a fragment is fine, e.g. an edit path).
  def expect_frame_breakout(body, href_includes)
    link = Nokogiri::HTML(body).at_css("a[href*='#{href_includes}']")
    expect(link).to be_present, "expected a link to #{href_includes} in the frame"
    expect(link["data-turbo-frame"]).to eq("_top"),
      "link to #{href_includes} is missing data-turbo-frame=\"_top\" (would Oopsie the frame)"
  end
end

RSpec.configure do |config|
  config.include TurboFrameBreakoutHelpers, type: :request
end
