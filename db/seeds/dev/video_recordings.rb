# VideoRecording seeds (dev-only) - run on their own via `rake db:seed:video_recordings`,
# or as part of `rake db:seed:dev`.

puts "Creating Video Recordings…"
[
  {
    title: "Getting Started: Your First Workshop",
    body: "A step-by-step guide to preparing and leading your first AWBW workshop.",
    youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    published: true,
    featured: true,
    publicly_visible: true,
    publicly_featured: true,
    position: 1,
    is_instructional: true,
    is_podcast: false
  },
  {
    title: "Trauma-Informed Facilitation Basics",
    body: "Learn the foundations of trauma-informed facilitation for art-based healing workshops.",
    youtube_url: "https://www.youtube.com/watch?v=jNQXAC9IVRw",
    published: true,
    featured: true,
    publicly_visible: true,
    publicly_featured: true,
    position: 2,
    is_instructional: true,
    is_podcast: false
  },
  {
    title: "Creating Safe Spaces for Art Expression",
    body: "How to set up your workshop environment to foster safety, trust, and creative expression.",
    youtube_url: "https://www.youtube.com/watch?v=9bZkp7q19f0",
    published: true,
    featured: true,
    publicly_visible: true,
    publicly_featured: true,
    position: 3,
    is_instructional: false,
    is_podcast: false
  },
  {
    title: "Working with Children and Youth",
    body: "Techniques and tips for adapting workshops for younger participants.",
    youtube_url: "https://www.youtube.com/watch?v=kJQP7kiw5Fk",
    published: true,
    featured: true,
    position: 4,
    is_instructional: false,
    is_podcast: false
  },
  {
    title: "Art Materials and Supply Management",
    body: "A practical guide to choosing, organizing, and budgeting for art supplies.",
    youtube_url: "https://www.youtube.com/watch?v=RgKAFK5djSk",
    published: true,
    featured: true,
    position: 5,
    is_instructional: false,
    is_podcast: false
  },
  {
    title: "Monthly Reporting Walkthrough",
    body: "How to complete your monthly reports and share workshop outcomes with AWBW.",
    youtube_url: "https://www.youtube.com/watch?v=JGwWNGJdvx8",
    published: true,
    featured: true,
    position: 6,
    is_instructional: false,
    is_podcast: true
  }
].each do |video_data|
  VideoRecording.where(title: video_data[:title]).first_or_create!(video_data)
end
