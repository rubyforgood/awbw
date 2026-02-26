puts "Creating Organizations…"
active_status = OrganizationStatus.find_by!(name: "Active")
inactive_status = OrganizationStatus.find_by!(name: "Inactive")
pending_status = OrganizationStatus.find_by!(name: "Pending")
suspended_status = OrganizationStatus.find_by!(name: "Suspended")

adult_wt = WindowsType.find_by!(short_name: "ADULT")
children_wt = WindowsType.find_by!(short_name: "CHILDREN")
combined_wt = WindowsType.find_by!(short_name: "COMBINED")

[
  { name: "1736 Family Crisis Center", organization_status: inactive_status, windows_type: adult_wt },
  { name: "Angel Step Inn", organization_status: active_status, windows_type: adult_wt },
  { name: "YWCA of San Diego - Becky's House", organization_status: active_status, windows_type: children_wt },
  { name: "Good Shepherd Shelter", organization_status: active_status, windows_type: adult_wt },
  { name: "One Safe Place", organization_status: active_status, windows_type: adult_wt },
  { name: "Haven Hills", organization_status: active_status, windows_type: children_wt },
  { name: "Survivor's Art Circle", organization_status: active_status, windows_type: children_wt },
  { name: "YWCA Spokane", organization_status: inactive_status, windows_type: adult_wt },
  { name: "Center for Battered Women", organization_status: pending_status, windows_type: children_wt },
  { name: "Asian Women Shelter", organization_status: active_status, windows_type: adult_wt },
  { name: "Deaf Hope", organization_status: active_status, windows_type: children_wt },
  { name: "YWCA of Monterey County", organization_status: active_status, windows_type: adult_wt },
  { name: "Joyful Heart Foundation", organization_status: suspended_status, windows_type: adult_wt },
  { name: "Domestic Violence Center of Santa Clarita Valley", organization_status: pending_status, windows_type: adult_wt },
  { name: "Abused Women's Aid in Crisis", organization_status: active_status, windows_type: adult_wt },
  { name: "Friends of the Family", organization_status: active_status, windows_type: adult_wt },
  { name: "Haven House", organization_status: active_status, windows_type: adult_wt },
  { name: "Laurel House", organization_status: active_status, windows_type: adult_wt },
  { name: "Alternatives for Battered Women", organization_status: active_status, windows_type: adult_wt },
  { name: "Humboldt Women for Shelter", organization_status: active_status, windows_type: children_wt }
].each do |org_data|
  Organization.where(name: org_data[:name]).first_or_create!(org_data)
end

puts "Creating Workshops…"
admin_user = User.find_by(email: "umberto.user@example.com")
[
  {
    title: "Comfort Journals",
    windows_type: adult_wt,
    full_name: "Rose Curtis",
    author_location: "Haven House, CA",
    month: 11,
    year: 1996,
    description: "Gives participants a window of time to think about what brings them comfort and nurturance and to collage related images onto a journal. End product is a journal that can be used as an ongoing reference and source of comfort.",
    pub_issue: "I/7",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-01 02:45:02")
  },
  {
    title: "Our Family Tree",
    windows_type: combined_wt,
    full_name: "Ellen Denninger",
    author_location: "Haven House, CA",
    month: 2,
    year: 1997,
    description: "Gives participants an opportunity to explore their sense of family and their place within it by using their hands to create a \"family tree.\"",
    pub_issue: "II/2",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-01 02:45:03")
  },
  {
    title: "Watercolor Windows",
    windows_type: adult_wt,
    full_name: "Cathy Salser",
    month: 3,
    year: 1997,
    description: "Offers survivors an opportunity to notice their inner and outer worlds, and to express their sense of self-transformation through the use of watercolors. Allows participants an opportunity to work successfully with the medium in a short time with rewarding results regardless of experience.",
    pub_issue: "II/3",
    published: true,
    featured: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-01 02:45:03")
  },
  {
    title: "Befriending Your Feelings",
    windows_type: adult_wt,
    full_name: "Shara Stevens",
    month: 4,
    year: 1997,
    description: "Allows participants an opportunity to explore and understand their feelings, know that all feelings are acceptable, and notice what their relationship to their feelings is like today. Participants do a series of quick, intuitive drawings, the focus being more on their experience than on the final product.",
    pub_issue: "II/4",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-01 02:45:04")
  },
  {
    title: "Story Dolls",
    windows_type: adult_wt,
    full_name: "Shara Stevens",
    month: 6,
    year: 1997,
    description: "Gives participants a voice to explore their abuse and what directions they can choose to take for their future. By externalizing their own story onto a doll, it becomes a safe place to explore, often becoming a way to discover feelings and thoughts never before claimed.",
    pub_issue: "II/6",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-01 02:45:04")
  },
  {
    title: "Ceremonial Staffs",
    windows_type: adult_wt,
    full_name: "Cate O'Hagan",
    author_location: "Central Oregon Arts Association, OR",
    month: 8,
    year: 1997,
    description: "Addresses the subjects of boundaries, saying no, self-respect and respect for others in an engaging, powerful way through the vehicle of the ancient symbols of the circle, ceremonial staff, and drumming. The end product, the ceremonial staff acts as a symbol of self-respect on which to focus and use as a tool in self-growth.",
    pub_issue: "II/8",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-01 02:45:05")
  },
  {
    title: "Peace Weavings",
    windows_type: adult_wt,
    full_name: "Julia Weaver",
    month: 10,
    year: 1997,
    description: "Shares a simple weaving method as a way for participants to express themselves creatively, learn about themselves and their world, and raise their self-esteem. The finished product is a woven journal cover.",
    pub_issue: "II/10",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-01 02:45:06")
  },
  {
    title: "Dreams and Goals Greeting Cards",
    windows_type: adult_wt,
    full_name: "Suzy Karcher Rogers",
    month: 2,
    year: 1998,
    description: "Provides a space of time for participants to think about dreams and goals for the future and to take those dreams and goals off \"hold.\" The end product is a decorated greeting card that the participant writes to themselves, reminding themselves in a positive voice of their desires for the future.",
    pub_issue: "III/2",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-01 02:45:07")
  },
  {
    title: "Blob Pictures",
    windows_type: children_wt,
    full_name: "Cordelia Roosevelt",
    month: 1,
    year: 1999,
    description: "Provides children with an opportunity to enjoy tearing the paper and making shapes, supporting each child in enjoying the surprise of selecting a shape and creating something out of it.",
    pub_issue: "II/1",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-01 02:45:14")
  },
  {
    title: "Rapping Puppets",
    windows_type: children_wt,
    full_name: "Lucy Rizo",
    month: 1,
    year: 2000,
    description: "Creates an opportunity for speaking out, offering a safe outlet for emotions of all kinds and, for children who feel they don't know how to express themselves through speech, a tool for exploring their own voice.",
    pub_issue: "III/1",
    published: true,
    featured: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-01 02:45:18")
  },
  {
    title: "My Butterfly",
    windows_type: adult_wt,
    full_name: "AWBW Staff",
    month: 1,
    year: 2001,
    description: "To offer participants a 'window of time' to notice their beautiful resilience. To give participants an opportunity to see their pain and challenges transform through a process of noticing their strengths, resources and wholeness. The end product is a reminder of how we can move through our trauma and come out stronger and more whole.",
    pub_issue: "IV/1",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-01 02:45:30")
  },
  {
    title: "New Year's Gardens",
    windows_type: children_wt,
    full_name: "Suzy Karcher Rogers",
    author_location: "Lancaster, Ohio",
    month: 1,
    year: 2003,
    description: "Gives children a chance to make a garden representing the important people and things in their lives and the opportunity to explore and express feelings about themselves and their world symbolically through shapes and colors.",
    pub_issue: "VI/1",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-01 02:45:42")
  },
  {
    title: "Feelings Collages",
    windows_type: adult_wt,
    full_name: "Carolyn Coleman Manns",
    author_location: "Laurel House, PA",
    month: 1,
    year: 2005,
    description: "This workshop was designed to give the participants a chance to focus on the ordeal they experienced which brought them into the shelter. To create a collage that can serve as a reminder of their strength and courage, and to be used as a reminder of why they left.",
    pub_issue: "VIII/1",
    published: true,
    featured: true,
    publicly_visible: true,
    publicly_featured: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-24 10:51:05")
  },
  {
    title: "Out with the Old and In with the New",
    windows_type: adult_wt,
    full_name: "Carrie Michel-Wynne",
    author_location: "Alternatives for Battered Women",
    month: 1,
    year: 2006,
    description: "By creating home-made \"sugar scrubs,\" this workshop gives participants a chance to explore what they would like to get rid of and what they would like to keep in their lives.",
    pub_issue: "IX/1",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-12-17 09:51:32")
  },
  {
    title: "Inspirational Scrolls",
    windows_type: adult_wt,
    full_name: "Anna Reyner",
    month: 8,
    year: 2008,
    description: "This workshop helps participants access their deepest feelings through the use of writing and Liquid Watercolors to create an Inspirational Scroll.",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2008-07-09 18:00:25")
  },
  {
    title: "Inner Self Portraits",
    windows_type: children_wt,
    full_name: "Rose Curtis",
    month: 9,
    year: 2009,
    description: "This workshop will assist older children and teens to look inside and discover more about their inner-self. We are used to looking at our outer selves, our looks, our clothes, our appearance, the image we try to portray. This workshop gives us an opportunity to go to a deeper level and get more in touch with our inner-self.",
    pub_issue: "XII/8",
    published: true,
    featured: true,
    publicly_visible: true,
    publicly_featured: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2009-08-25 14:50:19")
  },
  {
    title: "The Source of My Strength",
    windows_type: children_wt,
    full_name: "Anna Reyner",
    month: 7,
    year: 2010,
    description: "This workshop is designed to engage teens in a creative exercise to identify the things about them that are strong. They will create symbols that help represent the source of their own personal strength, so that they will be able to more quickly and readily understand their strengths and access them when needed.",
    pub_issue: "XIII/7",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2010-06-08 18:37:12")
  },
  {
    title: "Paying Attention to ME",
    windows_type: children_wt,
    full_name: "AWBW Staff",
    month: 5,
    year: 2011,
    description: "This workshop helps the children to focus on identifying their own personal needs to feel happy and healthy. Each child will create a Paying Attention to Me Doll that can serve as a reminder that they have unique needs.",
    pub_issue: "XIV/5",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2011-04-15 13:27:38")
  },
  {
    title: "Creating Joy",
    windows_type: children_wt,
    full_name: "Anna Reyner",
    month: 8,
    year: 2013,
    description: "Participants will explore, uncover, and identify their joy through a variety of creative exercises including paint, music, and movement.",
    pub_issue: "XVI/8",
    published: true,
    featured: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2013-07-11 17:04:14")
  },
  {
    title: "Personal Needs Flower",
    windows_type: adult_wt,
    full_name: "Karen Deborah Farris",
    month: 4,
    year: 2014,
    description: "This workshop provides an opportunity for participants to notice their personal needs by creating a flower where each petal represents one need. They will begin to see the many layers of needs\u2014physical, emotional and spiritual\u2014and to honor all these layers.",
    pub_issue: "VI/10",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-01 02:45:51")
  }
].each do |workshop_data|
  Workshop.where(title: workshop_data[:title]).first_or_create!(workshop_data)
end

puts "Assigning workshop categories and sectors…"
workshops = Workshop.all
categories = Category.all.to_a
sectors    = Sector.all.to_a

workshops.each do |workshop|
  rand(1..5).times do
    category = categories.sample
    next if category.nil?

    CategorizableItem.find_or_create_by!(
      category_id: category.id,
      categorizable_type: "Workshop",
      categorizable_id: workshop.id
    )
  end

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

puts "Creating Quotes…"
[
  { quote: "I love hearts, it makes me feel special, my mom will also feel special when I give my art to her." },
  { quote: "This workshop allows me to understand where I am coming from. I always look forward to coming to this class because I express myself through colors. I love to draw art even more while I am sober." },
  { quote: "The art workshop helped the kids feel more open to say why they are here, and the sharing helped them see that they had all been through the same things." },
  { quote: "I am here because it is nice and because my dad was trying to kill my mom." },
  { quote: "I'm going to miss doing art when we leave. I didn't think these groups were going to help me, but they have. I can be true to myself and open up and still be safe." },
  { quote: "AWBW is one of the avenues I chose so that I can make a difference in this world. I feel fortunate that I can help." },
  { quote: "I've been asking about a journal... Now I have one and I designed it myself! Great therapy!" },
  { quote: "This workshop was awesome and it helped me to realize that I am worthy of love and happiness. I am complete and perfect already!" },
  { quote: "It was the best day of my life!" },
  { quote: "It relieved a lot of pain and sadness. I love this class." },
  { quote: "The art fills the room with peace: it acts as a drug-free stress reliever!" },
  { quote: "I was able to forget my present feelings of overwhelming despair. I was able to focus on future accomplishments. After the rain there is always a blue sky and sunshine in the future." },
  { quote: "This was a visual aid reminding me that today I am not a victim, and that, with God, DV tools, and people to talk to, I can walk through anything." },
  { quote: "One lady said this workshop gave her so much inspiration that she feels now she can do anything. She moved out of state after that and is going to pursue her career in art that she has always wanted. She had a suitcase full of paintings and oils with her. Not many clothes, but she had her art! We have heard from her and she is doing great!" },
  { quote: "After doing the \"Funeral of 'I Can'ts'\" my client was finally ready to leave the abusive relationship and got a restraining order. She kept telling me that I did this for her and I told her \"No, it isn't me. It is you that did it. It is this program that did it!\"" },
  { quote: "You can read books and pamphlets, but I think with my hands making things. It works to wake up a part of me that was dead." },
  { quote: "This was me before: I was blind so my eyes were closed. I couldn't speak so my mouth was closed. I was quiet and now I am free to speak my mind and can see clearly." },
  { quote: "I made a sun because I love the sun. It's lighter on one side and growing stronger, and more fierce on the other side... kind of like how I'm changing too. I used to be less full of light, but I'm getting stronger and brighter." },
  { quote: "Looking at my suitcase I realized how far I have come and how much AWBW has helped me transform my life." },
  { quote: "I never thought an activity could make me feel so good. Right now I'm in love with myself." }
].each do |quote_data|
  Quote.where(quote: quote_data[:quote]).first_or_create!(quote_data)
end

puts "Creating Workshop-Quote links…"
seed_workshops = Workshop.where(title: [
  "Comfort Journals", "Watercolor Windows", "Befriending Your Feelings",
  "Story Dolls", "Ceremonial Staffs", "Peace Weavings",
  "Dreams and Goals Greeting Cards", "Blob Pictures", "Rapping Puppets",
  "My Butterfly", "Feelings Collages", "Inner Self Portraits",
  "The Source of My Strength", "Paying Attention to ME",
  "Creating Joy", "Personal Needs Flower",
  "Our Family Tree", "Inspirational Scrolls",
  "Out with the Old and In with the New", "New Year's Gardens"
]).to_a
seed_quotes = Quote.all.to_a

seed_quotes.each_with_index do |quote, i|
  workshop = seed_workshops[i % seed_workshops.size]
  next unless workshop

  QuotableItemQuote.find_or_create_by!(
    quotable: workshop,
    quote: quote
  )
end

puts "Creating Workshop Variations…"
variations = [
  {
    workshop_title: "Watercolor Windows",
    name: "Hope Prayers",
    rhino_body: "<p>As you guide the relaxation and painting process, you could focus on words that bring hope. For example strength, wisdom, courage, joy. The participants could imagine breathing these things in and painting them in shapes and colors.</p>",
    position: 20
  },
  {
    workshop_title: "Watercolor Windows",
    name: "Self-Care Prayers",
    rhino_body: "<p>As you guide the relaxation and painting process, you could imagine breathing in self-care, listening deeply for what we need to do to take care of ourselves, and noticing whatever shapes and colors come to mind.</p>",
    position: 15
  },
  {
    workshop_title: "Watercolor Windows",
    name: "Working from Quotes",
    rhino_body: "<p>Have a jar of inspirational quotes so each person can pick one without looking, see what the quote inspires in her, and then paint shapes and colors inspired by the quote.</p>",
    position: 5
  },
  {
    workshop_title: "Story Dolls",
    name: "Split Masks",
    rhino_body: "<p>When working with a group that was getting ready to leave the shelter, we did the Survival Masks project. Most of the participants chose to split the face on the mask. They painted the right side to represent the past and the left side to represent the future.</p>",
    position: 20
  },
  {
    workshop_title: "Story Dolls",
    name: "For Pregnant Teens",
    rhino_body: "<p>When leading Windows workshops with pregnant teens, they call me 'The Art Lady!' and are excited when I arrive at the Center. Doing the Debut CD project, I asked the girls to create a CD that would tell the story of themselves or their baby's debut into the world.</p>",
    position: 15
  },
  {
    workshop_title: "Befriending Your Feelings",
    name: "Then & Now Drawings",
    rhino_body: "<p>Draw an image of how it was to sleep while you were in the abusive relationship, and how you want sleep to be, now, when you are safe. Use Cray-Pas, crayons, markers, or pastels to express both experiences.</p>",
    position: 35
  },
  {
    workshop_title: "Befriending Your Feelings",
    name: "Dream-Catchers",
    rhino_body: "<p>Dream-Catchers come from the traditions of some Indigenous American tribes. They are meant to filter dreams, catching the bad ones and letting the good ones through. Participants create their own dream-catchers using paper plates, scissors, string, beads, feathers, and markers.</p>",
    position: 25
  },
  {
    workshop_title: "Comfort Journals",
    name: "Decorate with Super Sculpey",
    rhino_body: "<p>You can decorate your box with Super Sculpey instead of collage. To do this, roll out a piece of Super Sculpey to create a thin \"tortilla.\" Put the cover of your matchbox on the Super Sculpey and press gently to leave an outline. Cut out the shape and decorate.</p>",
    position: 20
  },
  {
    workshop_title: "Comfort Journals",
    name: "Binding into a Book",
    rhino_body: "<p>The paintings and words from any of these variations could be bound together into little books each person can use as a source of inspiration and strength. It could be a Personal Reminders Book or a collection of comfort imagery.</p>",
    position: 1
  },
  {
    workshop_title: "Peace Weavings",
    name: "Simple Variation",
    rhino_body: "<p>Just write with pens and markers on the paper feather pattern instead of using the foil and plastic wrap. This is a simpler version that works well with younger participants or when supplies are limited.</p>",
    position: 20
  },
  {
    workshop_title: "Peace Weavings",
    name: "Group Ornament",
    rhino_body: "<p>In this variation, everyone works on creating one large prayer ornament. The participants each put their prayer onto a small colored circle. Then they attach their small circles to the large ornament as a community piece.</p>",
    position: 15
  },
  {
    workshop_title: "Ceremonial Staffs",
    name: "Single Ornaments",
    rhino_body: "<p>In this variation, everyone makes individual ornaments that they can use to decorate a tree or the walls of the shelter. Making the ornaments card-like so they can open up allows participants to write personal messages inside.</p>",
    position: 20
  },
  {
    workshop_title: "Our Family Tree",
    name: "Growing, Step by Step",
    rhino_body: "<p>If the idea of looking into the past seems too difficult, you could call the workshop \"Growing, Step by Step\" and have each person use their three squares to illustrate a way they wish to grow in the coming months.</p>",
    position: 20
  },
  {
    workshop_title: "Dreams and Goals Greeting Cards",
    name: "Nap Permission Slips",
    rhino_body: "<p>Sometimes we are told that taking naps is lazy or bad. The truth is that naps can be deeply restorative. In this variation, participants create beautiful permission slips giving themselves permission to rest and recharge.</p>",
    position: 20
  },
  {
    workshop_title: "Inner Self Portraits",
    name: "Nap Goggles",
    rhino_body: "<p>Sometimes it is nice to have something soft and comforting pressing gently on your eyes when resting. In this variation, participants decorate flat, rectangular make-up sponges with acrylic paints and attach ribbons to create soothing nap goggles.</p>",
    position: 15
  },
  {
    workshop_title: "Feelings Collages",
    name: "Sweet-Dreams Pillows",
    rhino_body: "<p>Decorate or create a special Sweet-Dreams Pillow. Using fabric crayons and simple sewing supplies, participants design comforting pillows with imagery and words that represent safety and peace.</p>",
    position: 10
  },
  {
    workshop_title: "Creating Joy",
    name: "Guided Relaxation",
    rhino_body: "<p>This is not an art project but a supplementary relaxation exercise. Lay comfortably, ready for sleep. A guided relaxation is read aloud, helping participants focus on breathing and releasing tension throughout the body.</p>",
    position: 5
  },
  {
    workshop_title: "Personal Needs Flower",
    name: "Personal Symbols Keytags",
    rhino_body: "<p>Adapt the key-tags' meaning to be a personal symbol for participants to represent themselves. Each person creates a small, portable reminder of their identity and strengths that they can carry with them.</p>",
    position: 20
  },
  {
    workshop_title: "My Butterfly",
    name: "Tough Spot Prayers",
    rhino_body: "<p>With this variation, you could encourage each participant to notice a worry or challenge that she wants guidance or help with and put it into shapes and colors. Then through the process of painting, she can transform those feelings into something beautiful.</p>",
    position: 10
  },
  {
    workshop_title: "Inspirational Scrolls",
    name: "Sleep Rocks",
    rhino_body: "<p>Select a rock to be your special sleep rock. Using smooth rocks and paint pens, participants decorate their rocks with soothing imagery and words. The rock can be held while falling asleep as a grounding, comforting object.</p>",
    position: 30
  }
]

variations.each do |var_data|
  workshop = Workshop.find_by(title: var_data[:workshop_title])
  next unless workshop

  workshop.workshop_variations.where(name: var_data[:name]).first_or_create!(
    rhino_body: var_data[:rhino_body],
    position: var_data[:position]
  )
end

puts "Creating Persons and Affiliations for seed users…"
[
  User.find_by(email: "umberto.user@example.com"),
  User.find_by(email: "amy.user@example.com")
].compact.each do |user|
  next if user.person.present?

  person = Person.create!(
    first_name: user.first_name,
    last_name: user.last_name,
    email: user.email,
    created_by: user,
    updated_by: user,
    profile_is_searchable: true
  )
  user.update!(person: person)

  org = Organization.all.sample
  next unless org

  Affiliation.create!(
    person: person,
    organization: org,
    position: :leader,
    start_date: 1.year.ago.to_date
  )
end

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
].each_with_index do |title, i|
  visibility = if i < 3
    { published: true, featured: true }
  elsif i < 6
    { published: true, publicly_visible: true, publicly_featured: true }
  else
    { published: [ true, true, false ].sample, featured: [ true, false ].sample,
      publicly_visible: [ true, false ].sample, publicly_featured: [ true, false ].sample }
  end

  body_content = Faker::Lorem.paragraph(sentence_count: 6)
  CommunityNews.where(title: title)
               .first_or_create!(
                  rhino_body: "<p>#{body_content}</p>",
                  author_id: User.all.sample&.id,
                  created_by_id: User.first&.id,
                  updated_by_id: User.first&.id,
                  organization_id: Organization.all.sample&.id,
                  windows_type_id: WindowsType.all.sample&.id,
                  created_at: Time.current - rand(1..60).days,
                  updated_at: Time.current - rand(1..30).days,
                  **visibility
                )
end

puts "Creating new StoryIdeas…"
10.times do |i|
  body_content = Faker::Lorem.paragraph(sentence_count: 10)
  StoryIdea.create!(
    rhino_body: "<p>#{body_content}</p>",
    author_credit_preference: AuthorCreditable::AUTHOR_CREDIT_PREFERENCES.sample,
    permission_given: true,
    external_workshop_title: [ nil, nil, "Community Art Night", "Healing Arts Circle" ].sample,
    organization_id: Organization.all.sample&.id,
    workshop_id: Workshop.all.sample&.id,
    windows_type_id: WindowsType.all.sample&.id,
    youtube_url: [ nil, nil, "https://youtube.com/watch?v=dQw4w9WgXcQ",
                  "https://youtube.com/watch?v=abcd1234xyz" ].sample,
    created_by_id: User.first&.id,
    updated_by_id: User.first&.id,
    created_at: Time.current - rand(1..90).days,
    updated_at: Time.current - rand(1..40).days
  )
end

puts "Creating Stories…"
[
  "Healing Through Art: A Survivor's Journey",
  "Finding Strength in Creativity",
  "A Workshop Moment That Changed Everything",
  "From Silence to Expression",
  "Rediscovering Self-Worth Through Art",
  "Painting the Path to Healing",
  "A Child's Story of Safety and Hope",
  "Community Coming Together Through Workshops",
  "Leadership in Action: A Facilitator's Story",
  "When Art Opens a Door"
].each_with_index do |title, i|
  visibility = if i < 3
    { published: true, featured: true }
  elsif i < 6
    { published: true, publicly_visible: true, publicly_featured: true }
  else
    { published: [ true, true, false ].sample, featured: [ true, false ].sample,
      publicly_visible: [ true, false ].sample, publicly_featured: [ true, false ].sample }
  end

  body_content = Faker::Lorem.paragraph(sentence_count: 10)
  Story.where(title: title)
       .first_or_create!(
          rhino_body: "<p>#{body_content}</p>",
          permission_given: true,
          external_workshop_title: [ nil, nil, nil, nil, nil, nil, "Community Art Night", "Healing Arts Circle" ].sample,
          organization_id: Organization.all.sample&.id,
          workshop_id: [ nil, Workshop.all.sample&.id ].sample,
          story_idea_id: [ nil, nil, nil, nil, nil, nil, nil, nil, StoryIdea.all.sample&.id ].sample,
          windows_type_id: WindowsType.all.sample&.id,
          spotlighted_facilitator_id: [ nil, nil, nil, nil, Person.all.sample&.id ].sample,
          youtube_url: [
            nil,
            nil,
            "https://youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtube.com/watch?v=abcd1234xyz"
          ].sample,
          created_by_id: User.first&.id,
          updated_by_id: User.first&.id,
          created_at: Time.current - rand(1..90).days,
          updated_at: Time.current - rand(1..40).days,
          **visibility
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
].each_with_index do |title, i|
  start_date = Time.current + rand(5..60).days
  end_date   = start_date + rand(1..3).hours
  registration_close = start_date - rand(2..10).days

  visibility = if i < 3
    { published: true, featured: true }
  elsif i < 6
    { published: true, publicly_visible: true, publicly_featured: true }
  else
    { published: [ true, true, false ].sample, featured: [ true, false ].sample,
      publicly_visible: [ true, false ].sample, publicly_featured: [ true, false ].sample }
  end

  Event.where(title: title,
              start_date: start_date,
              end_date: end_date,)
       .first_or_create!(
    rhino_description: Faker::Lorem.paragraph(sentence_count: 6),
    registration_close_date: registration_close,
    created_by_id: User.first&.id,
    created_at: Time.current - rand(10..90).days,
    updated_at: Time.current - rand(1..30).days,
    **visibility
  )
end



puts "Creating new Resources…"
10.times do |i|
  kind = Resource::PUBLISHED_KINDS.sample

  visibility = if i < 3
    { published: true, featured: true }
  elsif i < 6
    { published: true, publicly_visible: true, publicly_featured: true }
  else
    { published: [ true, true, false ].sample, featured: [ true, false ].sample,
      publicly_visible: [ true, false ].sample, publicly_featured: [ true, false ].sample }
  end

  Resource.where(title: Faker::Book.title).first_or_create!(
    body: Faker::Lorem.paragraph(sentence_count: 8),
    author: [ Faker::Name.name, nil ].sample,
    agency: [ Faker::Company.name, nil ].sample,
    kind: kind,
    url: [ "https://example.com/resource/#{SecureRandom.hex(4)}", nil ].sample,
    inactive: false,
    legacy: [ true, false, false ].sample,
    legacy_id: rand(1000..9999),
    position: rand(1..50),
    windows_type_id: WindowsType.all.sample&.id,
    workshop_id: Workshop.all.sample&.id,
    created_by_id: User.all.sample&.id,
    created_at: Time.current - rand(20..120).days,
    updated_at: Time.current - rand(1..40).days,
    **visibility
  )
end

puts "Creating FAQs…"
faqs = [
  {
    id: 1, question: "Why art?",
    answer: %(
Art workshops provide a unique way to assist survivors of domestic violence in healing from the trauma of abuse, finding their voice, and building the courage to make healthy decisions for their future. For victims of domestic violence, art workshops provide a special "window" of support to share the complexity of their emotions, discover that they are not alone, and are not to blame for the violence. The art also helps survivors build healthy ways to handle anger and communicate non-violently.
    ), published: true, publicly_visible: true, ordering: 200
  },
  {
    id: 2, question: "What is the difference between the Windows Program and art therapy?",
    answer: %(
The AWBW workshops offer a process of self-expression, self-exploration, and self-interpretation. Unlike art therapy, there is no therapist or other authority responsible for interpretation or diagnosis. Each participant is in charge of her own creative exploration. For women and children who have been living under the control of another human being for so long, a simple art experience can provide a powerful opportunity to notice for the first time that they have the freedom to decide what they want to create. By placing the authority in the hands of each participant, the Windows workshops create an environment where survivors effectively support each other and take leadership in finding their own solutions.
    ), published: true, publicly_visible: true, ordering: 190
  },
  {
    id: 4, question: "I work with survivors of domestic violence. How can I bring the AWBW Program to my organization?",
    answer: %(
We welcome you to implement the Adult Windows Program or the Youth Windows Program at your organization. AWBW provides a comprehensive two-day training program for new leaders at our office/studio in Venice, California, or in other locations nationwide. Our training, facilitated by artists and experienced leaders, prepares you to bring the Windows Program to your organization. In some cases, we are also able to provide art supply allowances to help you get started. For all organizations that begin a Windows Program, AWBW provides permanent ongoing support including newsletters, leader's workshops, access to online leader support, and personalized consultation for as long as your program exists.
    ), published: true, ordering: 170
  },
  {
    id: 6, question: "How can I volunteer for A Window Between Worlds?",
    answer: %(
Contact us! We have a wide variety of volunteer opportunities for anyone who is available to donate some time in the Los Angeles area.
    ), published: true, ordering: 165
  },
  {
    id: 7, question: "I am a survivor. How can I participate in the art program?",
    answer: %(
You are welcome to participate in our Survivor's Art Circle, which provides support and encouragement for any domestic violence survivor wishing to use art as a healing tool. If you are in the Los Angeles area, you can attend monthly hands-on workshops with other survivors. If you are not in Los Angeles, you are welcome to participate in the online community of support. As part of the Survivor's Art Circle you will receive a monthly newsflash, and will be welcome to participate in group project ideas you can complete at home. You will also be welcome to participate in Survivor's Art Circle exhibition opportunities.
    ), published: true, publicly_visible: true, ordering: 140
  },
  {
    id: 12, question: "How do I get a scholarship for Leadership Training?",
    answer: %(
We award all scholarships based on need and availability of funds to agencies serving domestic violence clients. We ask those interested in applying for scholarship funding to submit a Scholarship Request 4 weeks in advance of the chosen training.
    ), published: true, ordering: 120
  },
  {
    id: 13, question: "I need more art supplies to hold my Windows Workshops. How can AWBW help?",
    answer: %(
AWBW awards Art Supply Scholarships to active reporting programs. All scholarship grants are based on need, availability of funds and strength of monthly reporting. Programs must report for a minimum of three months to be eligible to receive an art supply scholarship and must continue to hold weekly workshops and report monthly for a period of one year. AWBW programs that have been awarded art supply scholarships will be reimbursed for art supplies bought at any purveyor of their choosing as long as they submit receipts attached to AWBW's reimbursement form. AWBW also offers some free art supplies from our donated goods shopping area. Programs in good standing can make an appointment to "free shop" at our Venice location.
    ), published: true, ordering: 110
  },
  {
    id: 5, question: "I would like to volunteer to run art workshops at my local shelter. How can I get involved?",
    answer: %(
Due to confidentiality issues, art workshops are run by volunteers and staff who already work with a domestic violence agency, rather than outside volunteers. Contact your local domestic violence organization to find out about volunteer opportunities and whether or not they use the Windows Program. You will need to meet the individual agency's training requirements and get their permission and support to implement AWBW's program.
    ), published: true, ordering: 109
  },
  {
    id: 38, question: "Why Can We Train People Within Our Agency, But Not Train People Outside Our Agency?",
    answer: %(
1. We encourage you to train others within your agency because we want you to be able to do all you can to help your Windows groups become as strong and creative as possible. Over the years we've seen that the AWBW trained leaders can teach others quite effectively, and the new leaders they train also become a wonderful asset to the program.
2. There is a special process for training the trainers (for training beyond one's own agency). Otherwise many people who've been to only one training might want to start representing AWBW, and leading throughout beyond their agency, and we'd have no way of knowing if they were effective. There would also be no system of connecting what they are doing into the AWBW network of leaders.
3. Everything we do has been made possible by the network of leaders communicating and staying in touch with AWBW. The program and all that's been developed simply wouldn't exist without all the leaders sending their reports, insights and thoughts to AWBW so we can share them with everybody. So by leading the trainings we are able to make sure new agencies get the best shot possible at being closely connected to this network, so that it can thrive and continue.
    ), published: true, ordering: 108
  },
  {
    id: 39, question: "So How Can I Share AWBW With Other Agencies Within My Community?",
    answer: %(
These are some ways you can help other agencies start their own Windows Programs:
1. Share an introductory workshop with them (rather than a full training). Be sure to let us know you are doing it. That way we can help you pick a workshop to lead (if you want help) and we can give you the Workshop Feedback form to pass out. The form gives participants a way to get in touch with us so we can help them get further training so desire.
2. Encourage them to get trained (by either hosting a training, having distance learning, or coming to California).
3. Encourage them to take advantage of the scholarships we have through grant funding for the training in LA and the distance training.
4. If a leader works at your agency and then gets a job at another agency, they are welcome to contact us and let us know they are starting the program there. We will be happy to support them in starting a new program.
    ), published: true, ordering: 107
  },
  {
    id: 80, question: "How do I get the teens to trust their school counselors?",
    answer: %(
School counselors are not trained to be mandated reporters. Some counselors are friendly and some are not. Help the teens to ascertain which counselors are safe to talk to.
    ), published: true, ordering: 5
  },
  {
    id: 81, question: "Teen Dating FAQ's", answer: "tbd", published: true, ordering: 14
  }
]
faqs.each do |faq_data|
  Faq.find_or_initialize_by(id: faq_data[:id]).tap do |faq|
    faq.question = faq_data[:question]
    faq.answer   = faq_data[:answer]
    faq.published = faq_data[:published]
    faq.publicly_visible = faq_data[:publicly_visible] || false
    faq.position = faq_data[:ordering]
    faq.save!
  end
end

puts "Creating Tutorials…"
[
  {
    title: "Getting Started: Your First Workshop",
    rhino_body: "A step-by-step guide to preparing and leading your first AWBW workshop.",
    youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    published: true,
    featured: true,
    publicly_visible: true,
    publicly_featured: true,
    position: 1
  },
  {
    title: "Trauma-Informed Facilitation Basics",
    rhino_body: "Learn the foundations of trauma-informed facilitation for art-based healing workshops.",
    youtube_url: "https://www.youtube.com/watch?v=jNQXAC9IVRw",
    published: true,
    featured: true,
    publicly_visible: true,
    publicly_featured: true,
    position: 2
  },
  {
    title: "Creating Safe Spaces for Art Expression",
    rhino_body: "How to set up your workshop environment to foster safety, trust, and creative expression.",
    youtube_url: "https://www.youtube.com/watch?v=9bZkp7q19f0",
    published: true,
    featured: true,
    publicly_visible: true,
    publicly_featured: true,
    position: 3
  },
  {
    title: "Working with Children and Youth",
    rhino_body: "Techniques and tips for adapting workshops for younger participants.",
    youtube_url: "https://www.youtube.com/watch?v=kJQP7kiw5Fk",
    published: true,
    featured: true,
    position: 4
  },
  {
    title: "Art Materials and Supply Management",
    rhino_body: "A practical guide to choosing, organizing, and budgeting for art supplies.",
    youtube_url: "https://www.youtube.com/watch?v=RgKAFK5djSk",
    published: true,
    featured: true,
    position: 5
  },
  {
    title: "Monthly Reporting Walkthrough",
    rhino_body: "How to complete your monthly reports and share workshop outcomes with AWBW.",
    youtube_url: "https://www.youtube.com/watch?v=JGwWNGJdvx8",
    published: true,
    featured: true,
    position: 6
  }
].each do |tutorial_data|
  Tutorial.where(title: tutorial_data[:title]).first_or_create!(tutorial_data)
end
