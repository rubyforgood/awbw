require "rails_helper"

RSpec.describe "Story Share motion toggle", type: :system, js: true do
  let(:pause_button) { "button[aria-label='Pause videos and slideshows']" }
  let(:play_button) { "button[aria-label='Play videos and slideshows']" }

  def carousel_autoplay_running?
    page.evaluate_script("document.querySelector(\"[data-controller~='carousel']\").swiper.autoplay.running")
  end

  it "pauses the hero video and the carousel slideshow from one button" do
    create(:story, :published, :publicly_visible, title: "Video story",
           youtube_url: "https://www.youtube.com/watch?v=abc123", story_share_carousel_position: 1)
    create(:story, :published, :publicly_visible, title: "Photo story", story_share_carousel_position: 2)

    visit story_shares_path
    expect(page).to have_css(pause_button, count: 2)
    expect(carousel_autoplay_running?).to be(true)

    first(pause_button).click

    expect(page).to have_css("#{play_button} i.fa-play", count: 2)
    expect(carousel_autoplay_running?).to be(false)

    first(play_button).click

    expect(page).to have_css("#{pause_button} i.fa-pause", count: 2)
    expect(carousel_autoplay_running?).to be(true)
  end
end
