puts "Creating CommunityNews…"
[
  "Workshop Spotlight: Building Confidence Through Art",
  "New Facilitator Training Resources Released",
  "Creative Healing Story of the Month",
  "Leader Highlight: Supporting Survivors with Compassion",
  "New Workshop Series Launching This Spring",
  "Art-Based Tools for Emotional Safety",
  "Celebrating Community Voices",
  "Partner Site Success Story",
  "New Resources Added to the Library",
  "How Creativity Builds Connection"
].each do |title|
  CommunityNews.where(title: title)
               .first_or_create!(
                  body: Faker::Lorem.paragraph(sentence_count: 6),
                  featured: [ true, false ].sample,
                  published: [ true, true, true, false ].sample,
                  author_id: User.all.sample.id,
                  created_by_id: User.first.id,
                  updated_by_id: User.first.id,
                  project_id: Project.all.sample.id,
                  windows_type_id: WindowsType.all.sample.id,
                  created_at: Time.current - rand(1..60).days,
                  updated_at: Time.current - rand(1..30).days
                )
end

puts "Creating new StoryIdeas…"
10.times do |i|
  StoryIdea.create!(
    body: Faker::Lorem.paragraph(sentence_count: 10),
    publish_preferences: StoryIdea::PUBLISH_PREFERENCES.sample,
    permission_given: true,
    external_workshop_title: [ nil, nil, "Community Art Night", "Healing Arts Circle" ].sample,
    project_id: Project.all.sample.id,
    workshop_id: Workshop.all.sample&.id,
    windows_type_id: WindowsType.all.sample.id,
    youtube_url: [ nil, nil, "https://youtube.com/watch?v=dQw4w9WgXcQ",
                  "https://youtube.com/watch?v=abcd1234xyz" ].sample,
    created_by_id: User.first.id,
    updated_by_id: User.first.id,
    created_at: Time.current - rand(1..90).days,
    updated_at: Time.current - rand(1..40).days
  )
end

puts "Creating Stories…"
[
  "Healing Through Art: A Survivor’s Journey",
  "Finding Strength in Creativity",
  "A Workshop Moment That Changed Everything",
  "From Silence to Expression",
  "Rediscovering Self-Worth Through Art",
  "Painting the Path to Healing",
  "A Child’s Story of Safety and Hope",
  "Community Coming Together Through Workshops",
  "Leadership in Action: A Facilitator’s Story",
  "When Art Opens a Door"
].each do |title|
  Story.where(title: title)
       .first_or_create!(
          body: Faker::Lorem.paragraph(sentence_count: 10),
          featured: [ true, false, false, false, false, false ].sample,
          published: [ true, true, true, false ].sample,
          permission_given: true,
          external_workshop_title: [ nil, nil, nil, nil, nil, nil, "Community Art Night", "Healing Arts Circle" ].sample,
          project_id: Project.all.sample.id,
          workshop_id: [ nil, Workshop.all.sample&.id ].sample,
          story_idea_id: [ nil, nil, nil, nil, nil, nil, nil, nil, StoryIdea.all.sample&.id ].sample,
          windows_type_id: WindowsType.all.sample.id,
          spotlighted_facilitator_id: [ nil, nil, nil, nil, Facilitator.all.sample&.id ].sample,
          youtube_url: [
            nil,
            nil,
            "https://youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtube.com/watch?v=abcd1234xyz"
          ].sample,
          created_by_id: User.first.id,
          updated_by_id: User.first.id,
          created_at: Time.current - rand(1..90).days,
          updated_at: Time.current - rand(1..40).days
       )
end


puts "Creating Events…"
[
  "Healing Through Art: Spring Community Gathering",
  "Facilitator Training: Trauma-Informed Art Practices",
  "Youth Creativity Day",
  "Mindful Art for Survivors Workshop",
  "Community Open Studio Night",
  "Annual Celebration of Voices",
  "Art as Healing: Virtual Group Session",
  "Leaders in Creativity: Facilitator Roundtable",
  "Family Creative Expression Day",
  "Creative Safety & Support Workshop"
].each do |title|
  start_date = Time.current + rand(5..60).days
  end_date   = start_date + rand(1..3).hours
  registration_close = start_date - rand(2..10).days
  Event.where(title: title,
              start_date: start_date,
              end_date: end_date,)
       .first_or_create!(
    description: Faker::Lorem.paragraph(sentence_count: 6),
    featured: [ true, false ].sample,
    publicly_visible: [ true, true, false ].sample,
    registration_close_date: registration_close,
    created_by_id: User.first.id,
    created_at: Time.current - rand(10..90).days,
    updated_at: Time.current - rand(1..30).days
  )
end



puts "Creating new Resources…"
10.times do
  kind = Resource::PUBLISHED_KINDS.sample
  Resource.where(title: Faker::Book.title).first_or_create!(
    text: Faker::Lorem.paragraph(sentence_count: 8),
    author: [ Faker::Name.name, nil ].sample,
    agency: [ Faker::Company.name, nil ].sample,
    kind: kind,
    url: [ "https://example.com/resource/#{SecureRandom.hex(4)}", nil ].sample,
    featured: [ true, false ].sample,
    inactive: [ true, false, false ].sample, # mostly false = active
    legacy: [ true, false, false ].sample,
    legacy_id: rand(1000..9999),
    ordering: rand(1..50),
    windows_type_id: WindowsType.all.sample&.id,
    workshop_id: Workshop.all.sample&.id,
    user_id: User.all.sample&.id,
    created_at: Time.current - rand(20..120).days,
    updated_at: Time.current - rand(1..40).days
  )
end

puts "Creating FAQs…"
faqs = [
  {
    id: 1, question: "Why art?",
    answer: %(
Art workshops provide a unique way to assist survivors of domestic violence in healing from the trauma of abuse, finding their voice, and building the courage to make healthy decisions for their future. For victims of domestic violence, art workshops provide a special "window" of support to share the complexity of their emotions, discover that they are not alone, and are not to blame for the violence. The art also helps survivors build healthy ways to handle anger and communicate non-violently.
    ), inactive: false, ordering: 200
  },
  {
    id: 2, question: "What is the difference between the Windows Program and art therapy?",
    answer: %(
The AWBW workshops offer a process of self-expression, self-exploration, and self-interpretation. Unlike art therapy, there is no therapist or other authority responsible for interpretation or diagnosis. Each participant is in charge of her own creative exploration. For women and children who have been living under the control of another human being for so long, a simple art experience can provide a powerful opportunity to notice for the first time that they have the freedom to decide what they want to create. By placing the authority in the hands of each participant, the Windows workshops create an environment where survivors effectively support each other and take leadership in finding their own solutions.
    ), inactive: false, ordering: 190
  },
  {
    id: 4, question: "I work with survivors of domestic violence. How can I bring the AWBW Program to my organization?",
    answer: %{
We welcome you to implement the <a href="/awbw/programs-adult_windows.phjp">Adult Windows Program</a> or the <a href="/awbw/programs-youth_windows">Youth Windows Program</a> at your organization. AWBW provides a comprehensive two-day training program for new leaders at our office/studio in Venice, California, or in <a href="/awbw/programs-training_locations.php">other locations nationwide</a> (make this a link for non-local trainings?). Our training, facilitated by artists and experienced leaders, prepares you to bring the Windows Program to your organization. In some cases, we are also able to provide art supply allowances to help you get started. For all organizations that begin a Windows Program, AWBW provides permanent ongoing support including newsletters, leader's workshops, access to online leader support, and personalized consultation for as long as your program exists. Check for <a href="/awbw/programs-training.php">upcoming training opportunities</a>.
    }, inactive: false, ordering: 170
  },
  {
    id: 6, question: "How can I volunteer for A Window Between Worlds?",
    answer: %(
<a href="/awbw/contact.php">Contact us</a>! We have a wide variety of <a href="/awbw/volunteer.php">volunteer opportunities</a> for anyone who is available to donate some time in the Los Angeles area.
    ), inactive: false, ordering: 165
  },
  {
    id: 7, question: "I am a survivor. How can I participate in the art program?",
    answer: %(
You are welcome to participate in our <a href="/awbw/programs-sac.php">Survivor's Art Circle</a>, which provides support and encouragement for any domestic violence survivor wishing to use art as a healing tool. If you are in the Los Angeles area, you can attend monthly hands-on workshops with other survivors. If you are not in Los Angeles, you are welcome to participate in the online community of support. As part of the Survivor's Art Circle you will receive a monthly newsflash, and will be welcome to participate in group project ideas you can complete at home. You will also be welcome to participate in Survivor's Art Circle exhibition opportunities.
    ), inactive: false, ordering: 140
  },
  {
    id: 12, question: "How do I get a scholarship for Leadership Training?",
    answer: %(
We award all scholarships based on need and availability of funds to agencies serving domestic violence clients. We ask those interested in applying for scholarship funding to submit a <a href="/awbw/programs-leadership_training-scholarships_application.php">Scholarship Request</a> 4 weeks in advance of the chosen training. <a href="/awbw/programs-leadership_training-scholarships.php">Click here</a> to see the guidelines.
    ), inactive: false, ordering: 120
  },
  {
    id: 13, question: "I need more art supplies to hold my Windows Workshops. How can AWBW help?",
    answer: %(
AWBW awards Art Supply Scholarships to active reporting programs. All scholarship grants are based on need, availability of funds and strength of monthly reporting. Programs must report for a minimum of three months to be eligible to receive an art supply scholarship and must continue to hold weekly workshops and report monthly for a period of one year.<br /><br />AWBW programs that have been awarded art supply scholarships will be reimbursed for art supplies bought at any purveyor of their choosing as long as they submit receipts attached to AWBW’s reimbursement form.<br /><br />Visit our <a href="/awbw/programs-women_windows-art_supplies.php">recommended supply resource list</a> for information on where you can order art supplies.<br /><br />AWBW also offers some free art supplies from our donated goods shopping area. Programs in good standing can make an appointment to “free shop” at our Venice location.
    ), inactive: false, ordering: 110
  },
  {
    id: 5, question: "I would like to volunteer to run art workshops at my local shelter. How can I get involved?",
    answer: %(
Due to confidentiality issues, art workshops are run by volunteers and staff who already work with a domestic violence agency, rather than outside volunteers. Contact your local domestic violence organization to find out about volunteer opportunities and whether or not they use the Windows Program. You will need to meet the individual agency’s training requirements and get their permission and support to implement AWBW's program. Resource numbers you can call to find <a href="/awbw/contact-dv_resources.php">domestic violence organizations in your local area</a>.
    ), inactive: false, ordering: 109
  },
  {
    id: 38, question: "Why Can We Train People Within Our Agency, But Not Train People Outside Our Agency?",
    answer: %{
1. We encourage you to train others within your agency because we want you to be able to do all you can to help your Windows groups become as strong and creative as possible. Over the years we've seen that the AWBW trained leaders can teach others quite effectively, and the new leaders they train also become a wonderful asset to the program.<br />
2. There is a special process for training the trainers (for training beyond one's own agency). Otherwise many people who've been to only one training might want to start representing AWBW, and leading throughout beyond their agency, and we'd have no way of knowing if they were effective. There would also be no system of connecting what they are doing into the AWBW network of leaders. <br />
3. Everything we do has been made possible by the network of leaders communicating and staying in touch with AWBW. The program and all that's been developed simply wouldn't exist without all the leaders sending their reports, insights and thoughts to AWBW so we can share them with everybody. So by leading the trainings we are able to make sure new agencies get the best shot possible at being closely connected to this network, so that it can thrive and continue.
    }, inactive: false, ordering: 108
  },
  {
    id: 39, question: "So How Can I Share AWBW With Other Agencies Within My Community?",
    answer: %{
These are some ways you can help other agencies start their own Windows Programs:<br />
1. Share an introductory workshop with them (rather than a full training). Be sure to let us know you are doing it. That way we can help you pick a workshop to lead (if you want help) and we can give you the Workshop Feedback form to pass out. The form gives participants a way to get in touch with us so we can help them get further training so desire.<br />
2. Encourage them to get trained (by either hosting a training, having distance learning, or coming to California :-)<br />
3. Encourage them to take advantage of the scholarships we have through grant funding for the training in LA and the distance training.<br />
4. If a leader works at your agency and then gets a job at another agency, they are welcome to contact us and let us know they are starting the program there. We will be happy to support them in starting a new program.
    }, inactive: false, ordering: 107
  },
  {
    id: 80, question: "How do I get the teens to trust their school counselors?",
    answer: %(
School counselors are not trained to be mandated reporters. Some counselors are friendly and some are not. Help the teens to ascertain which counselors are safe to talk to.
    ), inactive: false, ordering: 5
  },
  {
    id: 81, question: "Teen Dating FAQ’s", answer: "tbd", inactive: false, ordering: 14
  }
]
faqs.each do |faq_data|
  Faq.find_or_initialize_by(id: faq_data[:id]).tap do |faq|
    faq.question = faq_data[:question]
    faq.answer   = faq_data[:answer]
    faq.inactive = faq_data[:inactive]
    faq.ordering = faq_data[:ordering]
    faq.save!
  end
end

puts "Creating workshops…"
workshops = [
  {
     title: "Comfort Journals",
     windows_type_id: 1,
     full_name: "Rose Curtis",
     user_id: User.find_by(first_name: "Rose", last_name: "Curtis")&.id,
     month: 11,
     year: 1996,
     description: "Gives participants a window of time to think about what brings them comfort and to collage related images onto a journal.",
     tips: "<span class='EmailHeader'></span><br><br>",
     inactive: true,
     searchable: true,
     created_at: Time.zone.parse("2005-03-01 02:45:02"),
     updated_at: Time.zone.parse("2015-10-19 19:19:04")
  },
  {
     title: "Inner Self Portraits",
     windows_type_id: 2,
     full_name: "Rose Curtis",
     user_id: User.find_by(first_name: "Rose", last_name: "Curtis")&.id,
     month: 9,
     year: 2009,
     description: "Helps children and teens discover more about their inner selves through mixed-media portrait creation.",
     tips: "<span class='EmailHeader'>Embodied art note…</span>",
     inactive: false,
     searchable: true,
     created_at: Time.zone.parse("2009-08-25 14:50:19"),
     updated_at: Time.zone.parse("2014-07-31 12:32:27")
  },
  {
     title: "New Year's Wish Marker",
     windows_type_id: 1,
     full_name: "Cathy Salser",
     user_id: User.find_by(first_name: "Cathy", last_name: "Salser")&.id,
     month: 12,
     year: 1996,
     description: "A relaxing collage-based visioning activity for the upcoming year.",
     inactive: false,
     searchable: true,
     created_at: Time.zone.parse("2005-03-01 02:45:02"),
     updated_at: Time.zone.parse("2012-11-29 18:00:09")
  },
  {
     title: "Gratitude Mandalas",
     windows_type_id: 2,
     full_name: "Maria Lopez",
     user_id: User.find_by(first_name: "Maria", last_name: "Lopez")&.id,
     month: 5,
     year: 2012,
     description: "Participants create mandalas focused on gratitude, calming the nervous system.",
     inactive: false,
     searchable: true,
     created_at: Time.zone.parse("2012-05-11 14:00:00"),
     updated_at: Time.zone.parse("2015-02-01 09:22:10")
  },
  {
     title: "Safe Spaces Collage",
     windows_type_id: 1,
     full_name: "Janelle Bishop",
     user_id: User.find_by(first_name: "Janelle", last_name: "Bishop")&.id,
     month: 2,
     year: 2015,
     description: "Explores what safety looks and feels like through imagery and symbolism.",
     inactive: false,
     searchable: true,
     created_at: Time.zone.parse("2015-02-02 10:10:10"),
     updated_at: Time.zone.parse("2016-01-20 08:01:22")
  },
  {
     title: "Strength Shields",
     windows_type_id: 2,
     full_name: "Tanya Nguyen",
     user_id: User.find_by(first_name: "Tanya", last_name: "Nguyen")&.id,
     month: 4,
     year: 2017,
     description: "Youth identify, draw, and claim their inner strengths using shield symbolism.",
     inactive: false,
     searchable: true,
     created_at: Time.zone.parse("2017-04-21 11:20:00"),
     updated_at: Time.zone.parse("2018-09-14 13:33:55")
  },
  {
     title: "Heart Mapping",
     windows_type_id: 1,
     full_name: "Clara James",
     user_id: User.find_by(first_name: "Clara", last_name: "James")&.id,
     month: 3,
     year: 2018,
     description: "Participants explore emotional landscapes by drawing and labeling heart maps.",
     inactive: false,
     searchable: true,
     created_at: Time.zone.parse("2018-03-14 09:40:00"),
     updated_at: Time.zone.parse("2019-05-11 16:02:10")
  },
  {
     title: "Calming Jars",
     windows_type_id: 3,
     full_name: "Rita Sanchez",
     user_id: User.find_by(first_name: "Rita", last_name: "Sanchez")&.id,
     month: 8,
     year: 2014,
     description: "A sensory activity that teaches emotional regulation through glitter jars.",
     inactive: false,
     searchable: true,
     created_at: Time.zone.parse("2014-08-08 12:12:00"),
     updated_at: Time.zone.parse("2016-06-10 12:12:10")
  },
  {
     title: "Identity Flags",
     windows_type_id: 2,
     full_name: "Samuel Brooks",
     user_id: User.find_by(first_name: "Samuel", last_name: "Brooks")&.id,
     month: 5,
     year: 2020,
     description: "Participants create symbolic flags representing identity, hopes, and values.",
     inactive: false,
     searchable: true,
     created_at: Time.zone.parse("2020-05-03 12:10:00"),
     updated_at: Time.zone.parse("2021-02-14 10:10:10")
  },
  {
     title: "Hope Collage", windows_type_id: 1,
     full_name: "Lena White",
     user_id: User.find_by(first_name: "Lena", last_name: "White")&.id,
     month: 6, year: 2019,
     description: "Exploring hope through creative collage.",
     notes: "", tips: "", pub_issue: "V/6",
     misc1: "", misc2: "", inactive: false, searchable: true,
     created_at: Time.zone.parse("2019-06-01"), updated_at: Time.zone.parse("2020-06-01")
  },
  {
     title: "Vision Boards", windows_type_id: 1,
     full_name: "Alicia Grant",
     user_id: User.find_by(first_name: "Alicia", last_name: "Grant")&.id,
     month: 1, year: 2021,
     description: "Creating intention for the year using collage boards.",
     notes: "", tips: "", pub_issue: "VI/1",
     misc1: "", misc2: "", inactive: false, searchable: true,
     created_at: Time.zone.parse("2021-01-10"), updated_at: Time.zone.parse("2021-05-01")
  },
  {
     title: "Emotions Wheel", windows_type_id: 3,
     full_name: "Ken Lo",
     user_id: User.find_by(first_name: "Ken", last_name: "Lo")&.id,
     month: 7, year: 2018,
     description: "Creating an expressive wheel of emotions.",
     notes: "", tips: "", pub_issue: "VII/4",
     misc1: "", misc2: "", inactive: false, searchable: true,
     created_at: Time.zone.parse("2018-07-07"), updated_at: Time.zone.parse("2019-08-02")
  },
  {
     title: "Memory Boxes", windows_type_id: 2,
     full_name: "Nicole Hart",
     user_id: User.find_by(first_name: "Nicole", last_name: "Hart")&.id,
     month: 9, year: 2013,
     description: "Participants decorate boxes to honor memories or transitions.",
     notes: "", tips: "", pub_issue: "III/7",
     misc1: "", misc2: "", inactive: false, searchable: true,
     created_at: Time.zone.parse("2013-09-09"), updated_at: Time.zone.parse("2014-03-12")
  },
  {
     title: "Courage Cards", windows_type_id: 1,
     full_name: "Heather James",
     user_id: User.find_by(first_name: "Heather", last_name: "James")&.id,
     month: 10, year: 2011,
     description: "Small creative cards with affirmations and courage statements.",
     notes: "", tips: "", pub_issue: "III/5",
     misc1: "", misc2: "", inactive: false, searchable: true,
     created_at: Time.zone.parse("2011-10-10"), updated_at: Time.zone.parse("2012-02-10")
  },
  {
     title: "Resilience Stones", windows_type_id: 1,
     full_name: "Barbara Kim",
     user_id: User.find_by(first_name: "Barbara", last_name: "Kim")&.id,
     month: 3, year: 2016,
     description: "Painting stones with messages about resilience.",
     notes: "", tips: "", pub_issue: "VIII/1",
     misc1: "", misc2: "", inactive: false, searchable: true,
     created_at: Time.zone.parse("2016-03-12"), updated_at: Time.zone.parse("2017-01-02")
  },
  {
     title: "Identity Trees", windows_type_id: 2,
     full_name: "Darius Lee",
     user_id: User.find_by(first_name: "Darius", last_name: "Lee")&.id,
     month: 2, year: 2014,
     description: "Participants draw trees where roots represent history and leaves represent hopes.",
     notes: "", tips: "", pub_issue: "IX/3",
     misc1: "", misc2: "", inactive: false, searchable: true,
     created_at: Time.zone.parse("2014-02-14"), updated_at: Time.zone.parse("2015-06-22")
  },
  {
     title: "Story Stones", windows_type_id: 3,
     full_name: "Ayana Cole",
     user_id: User.find_by(first_name: "Ayana", last_name: "Cole")&.id,
     month: 4, year: 2022,
     description: "Decorated stones used to tell collaborative stories.",
     notes: "", tips: "", pub_issue: "X/4",
     misc1: "", misc2: "", inactive: false, searchable: true,
     created_at: Time.zone.parse("2022-04-04"), updated_at: Time.zone.parse("2023-01-01")
  },
  {
     title: "Grief Lanterns", windows_type_id: 1,
     full_name: "Sofia Garza",
     user_id: User.find_by(first_name: "Sofia", last_name: "Garza")&.id,
     month: 10, year: 2020,
     description: "A mourning ritual using paper lanterns to honor losses.",
     notes: "", tips: "", pub_issue: "VI/9",
     misc1: "", misc2: "", inactive: false, searchable: true,
     created_at: Time.zone.parse("2020-10-10"), updated_at: Time.zone.parse("2021-07-07")
  },
  {
     title: "Calm Breathing Books", windows_type_id: 2,
     full_name: "Miguel Ortiz",
     user_id: User.find_by(first_name: "Miguel", last_name: "Ortiz")&.id,
     month: 6, year: 2015,
     description: "Folded books where each page guides a different calming breath.",
     notes: "", tips: "", pub_issue: "VIII/3",
     misc1: "", misc2: "", inactive: false, searchable: true,
     created_at: Time.zone.parse("2015-06-06"), updated_at: Time.zone.parse("2016-01-15")
  },
  {
     title: "Vision Tunnels", windows_type_id: 3,
     full_name: "Harriet Wu",
     user_id: User.find_by(first_name: "Harriet", last_name: "Wu")&.id,
     month: 1, year: 2023,
     description: "Paper tunnels layered with imagery representing goals for the year.",
     notes: "", tips: "", pub_issue: "XI/1",
     misc1: "", misc2: "", inactive: false, searchable: true,
     created_at: Time.zone.parse("2023-01-01"), updated_at: Time.zone.parse("2023-09-01")
  }
]
workshops.each do |workshop_data|
  Workshop.where(title: workshop_data[:title]).first_or_create!(workshop_data)
end

puts "Assigning workshop categories and sectors…"
workshops = Workshop.all
categories = Category.all.to_a
sectors    = Sector.all.to_a

workshops.each do |workshop|
  # --- Assign Categories --- #
  rand(1..5).times do
    category = categories.sample
    next if category.nil?

    CategorizableItem.find_or_create_by!(
      category_id: category.id,
      categorizable_type: "Workshop",
      categorizable_id: workshop.id
    )
  end

  # --- Assign Sectors --- #
  rand(1..3).times do
    sector = sectors.sample
    next if sector.nil?

    SectorableItem.find_or_create_by!(
      sector_id: sector.id,
      sectorable_type: "Workshop",
      sectorable_id: workshop.id
    )
  end
end
puts "Done assigning categories and sectors."


# Bookmark
# Stories
# # LeaderSpotlight
