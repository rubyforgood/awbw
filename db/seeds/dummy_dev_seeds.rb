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
    rhino_tips: '<span class="EmailHeader">Note About Introducing Embodied Art</span><br />Consider sharing with your participants the benefits of moving their bodies in playful and safe ways. Understanding what&rsquo;s meaningful about movement and body awareness can help participants feel at ease expanding their comfort zones. For more about embodied art workshops and how to introduce them in your groups, see <a href="/awbw/workshop.php?workshopid=3017&amp;dosearch=1&amp;windowstypeid=1&amp;searchtext=introduction&amp;submit.x=0&amp;submit.y=0" target="_blank">Introduction to Embodied Art Workshops</a>.<br /><br /><span class="EmailHeader">Note About Anger Workshops</span><br />We recommend that you start anger workshops with a discussion; don&#39;t be afraid to talk to the women about their anger.&nbsp;Anger is nothing to be ashamed of, it is important to look at and talk about it to try to understand it.<br /><br />Some anger prompts that we like are: <br />What is Anger? What does it look like and what does it sound like?<br />What was the trigger to your anger?<br />What did you think about it?<br />How did it make you feel?<br />How did you act?<br />What effect did it have on you and those around you?',
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
    rhino_tips: "Make sure that the socks are the right sizes for the participants hands.<br />",
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
    rhino_tips: "If yarn is not available, other random art supplies, such as gel pens, markers, sequins, and gems also work.<br />",
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
    rhino_tips: '<strong>Elvira Barnard </strong>of<strong> Chicana Service Action Center</strong> asked clients to bring their favorite poem to group to use in their art piece. <br /><br /><strong>Wendy Ball </strong>of <strong>Equinox, Inc. </strong>used these Inspirational Quotes as an examples:<br /><u>A Friendship Blessing:</u> <font size="1">(adapted from Anam Cara &ndash; a book of celtic wisdom by John O&rsquo;Donnohue)</font><br />May I be blessed with good friends.<br />May I learn to be a good friend to myself.<br />May I be able to journey to that place in my soul<br />where there is great love, warmth, feeling,<br />and forgiveness.<br />May this change me.<br />May it transfigure that which is negative,<br />distant, or cold in me.<br />May I be brought in to the real passion, kinship,<br />and affinity of belonging.<br />May I treasure my friends.<br />May I be good to them and may I be there for them;<br />May they bring me all the blessings, challenges,<br />truth, and light that I need for my journey.<br />May I never be isolated.<br />May I always be in the gentle nest of belonging<br />with my soul<br /><br /><u>A Blessing of Solitude:</u> <font size="1">(adapted from Anam Cara &ndash; a book of celtic wisdom by John O&rsquo;Donnohue)</font><br />May I recognize in my life the presence, power, and light of my soul.<br />May I realize that I am never alone,<br />that my soul in its brightness and belonging connects me intimately <br />with the rhythm of the universe.<br />May I have respect for my own<br />Individuality and difference.<br />May I realize that the shape of my soul is unique,<br />that I have a special destiny here,<br />that behind the fa&ccedil;ade of my life there is something beautiful, good and eternal happening.<br />May I learn to see myself with the same delight, pride, and expectation with which God sees me in every moment.<br /><br /><u>DV Affirmations:</u> (<font size="1">some affirmations from Melody Beattie)</font><br />I&rsquo;m no longer willing to lose my self esteem, self respect, my children&rsquo;s well-being, my job, home, possessions, safety, credit, my sanity or myself to preserve a relationship.<br /><br />I don&rsquo;t have to be willing to lose everything for love.<br /><br />I can learn to make appropriate choices concerning what I&rsquo;m willing to give in my relationships of myself, time, talents, and money<br /><br />As I develop healthy boundaries I am learning to respect others and myself.&nbsp; I am learning not to use or abuse others or allow them to use or abuse me.&nbsp; I no longer abuse myself!&nbsp; I am learning not to control others or let them control me.&nbsp; I am learning to stop taking responsibility for other people and stop letting them take responsibility for me.&nbsp; I am learning to take full responsibility for myself.<br /><br />I am proud of myself for accepting to take care of myself no matter what happens, where I go, or who I&rsquo;m with.<br /><br />I am proud of myself for believing that I deserve a better life and for acting on this belief.<br /><br />I have the right to take care of myself and to be myself.<br /><br />I am learning to value, trust and listen to myself.<br /><br />I am able to choose and to alter the direction of my life.<br /><br />I own and treasure my life!<br /><br />I am not stuck or trapped in a relationship.&nbsp; I have choices.&nbsp; I may not be able to see them clearly right now, but I do have choices.&nbsp; I am responsible for my choices.',
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
    rhino_tips: '<span class="EmailHeader">Note About Introducing Embodied Art<br /></span>Consider sharing with the youth the benefits of moving their bodies in playful and safe ways. By sharing this information with them, you empower them to feel a sense of ownership over their bodies and their expression. For more about embodied art workshops and how to introduce them in your groups, see <a href="/awbw/workshop.php?workshopid=3018&amp;dosearch=1&amp;windowstypeid=2&amp;searchtext=introduction&amp;submit.x=0&amp;submit.y=0" target="_blank">Introduction to Embodied Art Workshops</a>.',
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
    rhino_tips: "When selecting boxes to decorate, be sure to purchase ones that have an unfinished surface, similar to the one from Discount School Supply. A slick, or glossy surface will not allow the paint to stick.",
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
    rhino_tips: '<span class="TextHeader2"><span class="EmailHeader">Note About Conflicting Needs</span><br /></span>Sometimes a person might notice that their different needs seem to be in conflict with each other. (For example, the need to have more quiet alone time and the need to spend more playful, fun time with her children). This is okay. The purpose of this workshop is to reveal the many needs that can be seen as part of our entire makeup. It is okay not to be problem-solving at this time, but rather supporting participants as they reveal and learn to accept themselves at this creative stage, seeing not only the needs that can be fulfilled, but also those that seem far from resolution. By putting all the needs around a single circle, we allow our conscious mind to see how they all can coexist and we can begin to find safer and more creative ways to embrace and move through any conflicts.<span class="TextHeader2"></span><br /><br /><span class="EmailHeader">Note About Introducing Embodied Art<br /></span>Consider sharing with your participants the benefits of moving their bodies in playful and safe ways.&nbsp; Understanding what&rsquo;s meaningful about movement and body awareness can help participants feel at ease expanding their comfort zones. For more about embodied art workshops and how to introduce them in your groups, see <a href="/awbw/workshop.php?workshopid=3017&amp;dosearch=1&amp;windowstypeid=1&amp;searchtext=introduction&amp;submit.x=0&amp;submit.y=0" target="_blank">Introduction to Embodied Art Workshops</a>.',
    pub_issue: "VI/10",
    published: true,
    searchable: true,
    created_by: admin_user,
    created_at: Time.zone.parse("2005-03-01 02:45:51")
  }
].each do |workshop_data|
  workshop_data[:tips] = workshop_data[:rhino_tips] if workshop_data[:rhino_tips]
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
# rubocop:disable Style/PercentLiteralDelimiters
variations = [
  {
    workshop_title: "Watercolor Windows",
    name: "Hope Prayers",
    rhino_body: %[As you guide the relaxation and painting process, you could focus on words that bring hope.&nbsp; For example strength, wisdom, courage, joy.&nbsp; The participants could imagine breathing these things in, feeling them fill their bodies, and express them in shapes and colors in their paintings.],
    position: 20
  },
  {
    workshop_title: "Watercolor Windows",
    name: "Self-Care Prayers",
    rhino_body: %[As you guide the relaxation and painting process, you could imagine breathing in self-care, listening deeply for what we need to do to take care of ourselves, and noticing whatever shapes and colors come to mind as we think of taking care of ourselves.],
    position: 15
  },
  {
    workshop_title: "Watercolor Windows",
    name: "Working from Quotes",
    rhino_body: %[Have a jar of inspirational quotes so each person can pick one without looking, see what they quote inspires in her, and then paint shapes and colors inspired by the quote.&nbsp; (see enclosed list to copy and cut up for your jar).<br />Or:<br />Hand out the entire list of inspirational quotes to each participant so she can read them, choose her favorite ones, and then create paintings expressing these quotes in shapes and<br />colors.],
    position: 5
  },
  {
    workshop_title: "Story Dolls",
    name: "Split Masks",
    rhino_body: %[Recently when I was working with a group that was getting ready to leave the shelter, we did the Survival Masks project. &nbsp;<br/><br/>Most of the participants chose to split the face on the mask.&nbsp; They created one side to represent what they came to the shelter as and the other side to represent what they were leaving with. &nbsp;<br/><br/>It was incredibly powerful for them to actually see the difference and acknowledge their growth.&nbsp; It was fascinating for all of us to see their change so clearly. &nbsp;<br/><br/>When they left the shelter they very carefully packed their art work between their clothing, so they could keep it protected!],
    position: 20
  },
  {
    workshop_title: "Story Dolls",
    name: "For Pregnant Teens",
    rhino_body: %[I lead Windows workshops with pregnant teens. They call me &lsquo;The Art Lady!&rsquo; and are excited when I arrive at the Center. &nbsp;<br/><br/>Doing the Debut CD project, I asked the girls to create a CD that would express the message that they want to tell their child.&nbsp; After the project, one of the teen moms who had been very dependant on her boyfriend said, &lsquo;Never have a baby because you are lonely.&rsquo;&nbsp; This was a major moment of self-awareness for her.<br/><br/>It made me smile recently when one new girl told me she had heard about the Windows groups and she was looking forward to it because it would give her a break from &lsquo;having&rsquo; to talk about feelings &ndash; but little did she know, they talk about feelings all the time through their art!],
    position: 15
  },
  {
    workshop_title: "Befriending Your Feelings",
    name: "Then & Now Drawings",
    rhino_body: %[<span class="TextHeader2">Materials:</span><br/>Cray-Pas (or crayons, markers, pastels, etc.) and paper<br/><br/><span class="TextHeader2">Project:</span><br/>Draw an image of how it was to sleep while you were in the abusive relationship, and how you want sleep to be, now, when you are free of the abusive relationship.&nbsp; Put words into the drawings as needed.<br/>],
    position: 35
  },
  {
    workshop_title: "Befriending Your Feelings",
    name: "Dream-Catchers",
    rhino_body: %[<span class="TextHeader2">Materials:</span><br/>Strong paper plates, scissors, string, hole-punches, beads, feathers, markers<br/><br/><span class="TextHeader2">Project:</span> <br/>Dream-Catchers come from the traditions of some Indigenous American tribes.&nbsp; They are based on the belief that dreams are messages sent to us from sacred beings during our sleep.&nbsp; The Dream-Catchers, web-like hoops are placed by our heads during sleep so that they can catch the bad dreams (messages) and permit the good ones to pass through and reach our minds during sleep.&nbsp; Then, when the rays of the sun come up in the morning the bad dreams are burnt away and therefore we are only left with the good ones.&nbsp; (A simplified way of creating Dream-Catchers is written in the AWBW Children&rsquo;s Windows Manual.&nbsp; If you need a copy of the workshop, let us know.)<br/>],
    position: 25
  },
  {
    workshop_title: "Comfort Journals",
    name: "Decorate with Super Sculpey",
    rhino_body: %[You can decorate your box with Super Sculpey instead of collage.&nbsp; To do this, roll out a piece of Super Sculpey to create a thin Super Sculpey &quot;tortilla.&quot;&nbsp; Put the cover of your match-box in the middle of this &quot;tortilla&quot; and cover the outside of it with this.&nbsp; Cut excess on side with an Exacto knife - DON'T FOLD THE CLAY OVER THE EDGE INTO THE INSIDE OF THE BOX BECAUSE YOU WON'T BE ABLE TO OPEN AND CLOSE THE BOX.&nbsp; Make a second &quot;tortilla&quot; for the other side of the cover.&nbsp; Use Super Sculpey to create a 3-dimentional design on top of the box.&nbsp; Make flowers or&nbsp; abstract shapes and then place them on top of the Super Sculpey &quot;tortilla&quot;&nbsp; layer that is in place.&nbsp; Be sure to press them in&mdash;don't just place them on top.&nbsp; Once finished, bake it in the oven like usual.&nbsp; The Super Sculpey protects the box from burning, but keep checking the oven.&nbsp; If your box has a lot of pieces sticking out of it, paint a couple of thin layers of Gesso to make the Super Sculpey a little tougher so it won't break apart while you paint it (or afterwards).&nbsp; Now paint the Super Sculpey.&nbsp; Once dried (you might have to wait a while), cover the whole work with a layer of Mod-Podge to give it shine and to protect the paint.],
    position: 20
  },
  {
    workshop_title: "Comfort Journals",
    name: "Binding into a Book",
    rhino_body: %[The paintings and words from any of these variations could be bound together into little books each person can use as a source of inspiration and strength. It could be her Personal Reminders Book, her Personal Rulebook, her Personal Inspiration Book. Each woman could come up with her own title and purpose for how she wants to use her book.],
    position: 1
  },
  {
    workshop_title: "Peace Weavings",
    name: "Simple Variation",
    rhino_body: %[Just write with pens and markers on the paper feather pattern instead of using the foil and plastic wrap.],
    position: 20
  },
  {
    workshop_title: "Peace Weavings",
    name: "Group Ornament",
    rhino_body: %[In this variation, everyone works on creating one large prayer ornament.&nbsp; The participants each put their prayer onto a small colored circle.&nbsp; Then they attach their small circles to the larger one using a hole punch and ribbons.&nbsp; It ends up looking sort of like an advent calendar where you can open up individual circles.<br/>],
    position: 15
  },
  {
    workshop_title: "Ceremonial Staffs",
    name: "Single Ornaments",
    rhino_body: %[In this variation, everyone makes individual ornaments that they can use to decorate a tree or the walls of the shelter.&nbsp; I recommend making the ornaments card-like so they can open up.&nbsp; Decorate the front as an art gift to God and write the prayer inside.&nbsp; Use a hole punch and ribbon to hang each one.],
    position: 20
  },
  {
    workshop_title: "Our Family Tree",
    name: "Growing, Step by Step",
    rhino_body: %[If the idea of looking into the past seems too difficult, you could just call the workshop &ldquo;Growing, Step by Step&rdquo; and have each person use their three squares to illustrate a way they wish to grow, step by step. <br/>],
    position: 20
  },
  {
    workshop_title: "Dreams and Goals Greeting Cards",
    name: "Nap Permission Slips",
    rhino_body: %[<span class="TextHeader2">Materials:</span><br/>Colored construction paper, scissors, markers, Cray-Pas, hole puncher, ribbons<br/> <br/><span class="TextHeader2">Project:</span><br/>Sometimes we are told that taking naps is lazy or bad.&nbsp; The truth is that naps can be a very important part of recovering from stresses and gaining strength and clarity.&nbsp; Write for yourself permission slips to nap.&nbsp; Decorate them with ribbons, designs, whatever will help remind you that naps are a very good thing.&nbsp; (You might want to check out a wonderful book by Sark: <span style="font-style: italic;">Change Your Life Without Getting Out of Bed:&nbsp; The Ultimate Nap Book</span>.)],
    position: 20
  },
  {
    workshop_title: "Inner Self Portraits",
    name: "Nap Goggles",
    rhino_body: %[<span class="TextHeader2">Materials:</span><br/>Flat, rectangular make-up sponges, ribbons, scissors, acrylic paints, brushes, water<br/> <span class="TextHeader2">Project:</span> <br/>Sometimes it is nice to have something soft and comforting pressing gently on your eyes, blocking out the light, and reminding you it&rsquo;s okay to sleep.&nbsp; (This can be especially important for day-time naps!)&nbsp; To tie your goggles together, gently poke a hole in the sponge with the tip of scissors.&nbsp; Then poke the ribbon through with the scissor tip to thread.&nbsp; (Poke gently!&nbsp; The sponges can rip.)&nbsp; Tie your goggles together in the center to fit over your nose.&nbsp; Then tie the outside ribbon to fit around your head. When you are ready, paint on the outside of them whatever images remind you of the deep, delicious rest that you deserve everyday.<br/>],
    position: 15
  },
  {
    workshop_title: "Feelings Collages",
    name: "Sweet-Dreams Pillows",
    rhino_body: %[<span class="TextHeader2">Materials:</span><br/>Supplies for hand-sewing mini pillows (fabric, thread, stuffing, etc. or ready-made pillow cases to decorate, if available), fabric crayons, newspaper, an electric iron<br/><br/><span class="TextHeader2">Project:</span><br/>Decorate or create for yourself a special Sweet-Dreams Pillow.&nbsp; Cover it with whatever images, colors and words will help you sleep deeply.&nbsp; Use your pillow to create your safe &ldquo;nest&rdquo; for your deep wonderful rests.],
    position: 10
  },
  {
    workshop_title: "Creating Joy",
    name: "Guided Relaxation",
    rhino_body: %[<span class="TextHeader2">Materials:</span><br/>Copies of a favorite guided relaxation to hand out (see page 5 for sample, audio tapes and tape recorder (optional)<br/><br/><span class="TextHeader2">Description:</span><br/>This is not an art project.&nbsp; It is a supplementary suggestion for help with sleeping.&nbsp; Using a guided relaxation can be a marvelous way to relax and fall asleep, when you feel tense or unable to sleep.&nbsp; The relaxation can be recorded, or memorized.&nbsp; For those who have tape players, it is wonderful to have the relaxation on tape, so they can listen and fall asleep, rather than trying to remember the relaxation.&nbsp; Distribute copies of the sample relaxation, and encourage participants to take their copy with them and to change it as they wish.&nbsp; If taping is possible, you might set up the equipment for this in a separate room.&nbsp; That way, those who wish to make themselves a sleep relaxation tape may do so, one at a time, throughout the art workshop.&nbsp; &nbsp;<br/><br/><br/><span style="font-weight: bold;">Guided Relaxation for Peaceful Sleep</span><br style="font-weight: bold;"/>Lay comfortably in your bed, ready for sleep.&nbsp; Adjust your arms and legs so that they are comfortable and settled. Notice your breathing...Now take some deep breaths in, and as you let each one out, say to yourself, &ldquo;relax&rdquo;... &nbsp;<br/><br/>When you are ready, become aware of your face.&nbsp; Notice your whole head and neck.&nbsp; Now take a deep breath in, and squeeze the muscles in your face, head, and neck.&nbsp; Now let your breath go and release all the tension from your head.&nbsp; As you relax your head, picture the relaxation spreading through your entire body. &nbsp;<br/><br/>Repeat above sequence for these: <br/>*shoulders and back* &nbsp;<br/>*arms and hands* &nbsp;<br/>*chest and stomach* <br/>*legs and feet* <br/><br/>Now take another deep breath for your entire body.&nbsp; Gently tense the muscles from head to toe, one more time, and release.&nbsp; Feel the tension melting away with your breath. &nbsp;<br/><br/>Rest comfortably in this position.&nbsp; Just enjoy how relaxed your whole body is, as you drift off to a deep, peaceful and refreshing sleep.],
    position: 5
  },
  {
    workshop_title: "Personal Needs Flower",
    name: "Personal Symbols Keytags",
    rhino_body: %[&nbsp;I would suggest adapting the key-tags&#39; meaning to be a personal symbol for them to represent themselves.],
    position: 20
  },
  {
    workshop_title: "My Butterfly",
    name: "Tough Spot Prayers",
    rhino_body: %[With this variation, you could encourage each participant to notice a worry or challenge that she wants guidance or help with and put it into shapes and colors. Then through the process<br />of painting that shape in consecutive paintings, she can see what emerges and how it transforms, just in shapes and colors, exploring how that challenge can be resolved or transformed.],
    position: 10
  },
  {
    workshop_title: "Inspirational Scrolls",
    name: "Sleep Rocks",
    rhino_body: %[<span class="TextHeader2">Materials:</span><br/>Smooth rocks (can be purchased at garden and home supply places), paint pens (any opaque pens that can write on rocks)<br/> <br/><span class="TextHeader2">Project:</span><br/>Select a rock to be your special sleep rock.&nbsp; Hold it and let your eyes close.&nbsp; As you rest with your rock, notice what thoughts your rock holds for you.&nbsp; What thoughts about sleep, about resting, about you?&nbsp; What words come to mind?&nbsp; When you are ready, write these words on your rock.],
    position: 30
  }
]

# rubocop:enable Style/PercentLiteralDelimiters
variations.each do |var_data|
  workshop = Workshop.find_by(title: var_data[:workshop_title])
  next unless workshop

  workshop.workshop_variations.where(name: var_data[:name]).first_or_create!(
    body: var_data[:rhino_body],
    rhino_body: var_data[:rhino_body],
    position: var_data[:position]
  )
end

puts "Creating Persons and Affiliations for seed users…"
[
  User.find_by(email: "umberto.user@example.com"),
  User.find_by(email: "amy.user@example.com"),
  User.find_by(email: "priya.user@example.com")
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

puts "Creating People…"
admin_user = User.find_by(email: "umberto.user@example.com")
orgs = Organization.all.to_a

test_people = [
  # --- Johnson cluster (8 people, similar last names) ---
  { first_name: "Maria", last_name: "Johnson", email: "maria.johnson@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 2 },
  { first_name: "Maria", last_name: "Johnston", email: "maria.johnston@yahoo.com", email_2: "mj@work.org", searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Marie", last_name: "Johnson", email: "marie.j@outlook.com", email_2: nil, searchable: true, with_user: true, affiliations: 0 },
  { first_name: "Mario", last_name: "Johnson", email: nil, email_2: nil, searchable: true, with_user: false, affiliations: 1 },
  { first_name: "Mark", last_name: "Johnson", email: "mark.johnson@hotmail.com", email_2: nil, searchable: false, with_user: true, affiliations: 1 },
  { first_name: "Mary", last_name: "Johnson", email: nil, email_2: "mary.j@backup.org", searchable: true, with_user: false, affiliations: 0 },
  { first_name: "Mariana", last_name: "Johnson", email: "mariana@johnson.com", email_2: nil, searchable: true, with_user: true, affiliations: 3 },
  { first_name: "Marcus", last_name: "Johnstone", email: "marcus.j@example.com", email_2: nil, searchable: true, with_user: false, affiliations: 1 },

  # --- Garcia cluster (7 people) ---
  { first_name: "Ana", last_name: "Garcia", email: "ana.garcia@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Anna", last_name: "Garcia", email: "anna.garcia@yahoo.com", email_2: nil, searchable: true, with_user: true, affiliations: 2 },
  { first_name: "Ana Maria", last_name: "Garcia", email: nil, email_2: "anamaria@personal.net", searchable: true, with_user: false, affiliations: 0 },
  { first_name: "Andrea", last_name: "Garcia", email: "andrea.g@outlook.com", email_2: nil, searchable: false, with_user: true, affiliations: 1 },
  { first_name: "Angel", last_name: "Garcia", email: nil, email_2: nil, searchable: true, with_user: false, affiliations: 1 },
  { first_name: "Ana", last_name: "Garcia-Lopez", email: "ana.gl@work.org", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Antonio", last_name: "Garcia", email: "antonio.garcia@gmail.com", email_2: "tony.g@backup.com", searchable: true, with_user: false, affiliations: 0 },

  # --- Smith cluster (7 people) ---
  { first_name: "Sarah", last_name: "Smith", email: "sarah.smith@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Sara", last_name: "Smith", email: "sara.smith@yahoo.com", email_2: nil, searchable: true, with_user: true, affiliations: 0 },
  { first_name: "Samuel", last_name: "Smith", email: nil, email_2: "sam.smith@backup.org", searchable: true, with_user: false, affiliations: 2 },
  { first_name: "Sandra", last_name: "Smith", email: "sandra.s@outlook.com", email_2: nil, searchable: false, with_user: true, affiliations: 1 },
  { first_name: "Sarah", last_name: "Smithson", email: "sarah.smithson@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Sarah Jane", last_name: "Smith", email: nil, email_2: nil, searchable: true, with_user: false, affiliations: 1 },
  { first_name: "Santiago", last_name: "Smith", email: "santiago.smith@hotmail.com", email_2: "santi@alt.org", searchable: true, with_user: true, affiliations: 0 },

  # --- Williams cluster (6 people) ---
  { first_name: "Lisa", last_name: "Williams", email: "lisa.williams@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Lisa", last_name: "Williamson", email: "lisa.williamson@yahoo.com", email_2: nil, searchable: true, with_user: true, affiliations: 2 },
  { first_name: "Linda", last_name: "Williams", email: nil, email_2: "linda.w@backup.com", searchable: true, with_user: false, affiliations: 0 },
  { first_name: "Luis", last_name: "Williams", email: "luis.w@outlook.com", email_2: nil, searchable: false, with_user: false, affiliations: 1 },
  { first_name: "Lily", last_name: "Williams", email: "lily.williams@hotmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Lisa Marie", last_name: "Williams", email: nil, email_2: nil, searchable: true, with_user: false, affiliations: 0 },

  # --- Brown cluster (6 people) ---
  { first_name: "Jessica", last_name: "Brown", email: "jessica.brown@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 2 },
  { first_name: "Jennifer", last_name: "Brown", email: "jennifer.b@yahoo.com", email_2: "jen.brown@alt.org", searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Jessica", last_name: "Browning", email: nil, email_2: nil, searchable: true, with_user: false, affiliations: 1 },
  { first_name: "Jesse", last_name: "Brown", email: "jesse.brown@outlook.com", email_2: nil, searchable: false, with_user: true, affiliations: 0 },
  { first_name: "Jenna", last_name: "Brown", email: nil, email_2: "jenna.b@backup.net", searchable: true, with_user: false, affiliations: 1 },
  { first_name: "Jean", last_name: "Brown", email: "jean.brown@hotmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 0 },

  # --- Davis cluster (5 people) ---
  { first_name: "Kim", last_name: "Davis", email: "kim.davis@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Kimberly", last_name: "Davis", email: "kimberly.d@yahoo.com", email_2: nil, searchable: true, with_user: true, affiliations: 0 },
  { first_name: "Kim", last_name: "Davidson", email: nil, email_2: "kim.dav@backup.org", searchable: true, with_user: false, affiliations: 2 },
  { first_name: "Karen", last_name: "Davis", email: "karen.davis@outlook.com", email_2: nil, searchable: false, with_user: true, affiliations: 1 },
  { first_name: "Katherine", last_name: "Davis", email: nil, email_2: nil, searchable: true, with_user: false, affiliations: 1 },

  # --- De La Cruz cluster (5 people, spaces in last name) ---
  { first_name: "Rosa", last_name: "De La Cruz", email: "rosa.dlc@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Rosalia", last_name: "De La Cruz", email: nil, email_2: "rosalia@backup.net", searchable: true, with_user: false, affiliations: 0 },
  { first_name: "Rosa Maria", last_name: "De La Cruz", email: "rosamaria.dlc@yahoo.com", email_2: nil, searchable: true, with_user: true, affiliations: 2 },
  { first_name: "Roberto", last_name: "De La Cruz", email: nil, email_2: nil, searchable: false, with_user: false, affiliations: 1 },
  { first_name: "Rosario", last_name: "De La Cruz-Santos", email: "rosario.dlcs@outlook.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },

  # --- Mixed singles (6 people, similar first names across families) ---
  { first_name: "Maria", last_name: "De La Cruz", email: "maria.dlc@hotmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Maria", last_name: "Smith", email: nil, email_2: "maria.smith@backup.org", searchable: true, with_user: false, affiliations: 0 },
  { first_name: "Maria", last_name: "Williams", email: "maria.w@gmail.com", email_2: nil, searchable: true, with_user: true, affiliations: 1 },
  { first_name: "Sarah", last_name: "Garcia", email: "sarah.garcia@yahoo.com", email_2: nil, searchable: true, with_user: true, affiliations: 0 },
  { first_name: "Sarah", last_name: "Brown", email: nil, email_2: nil, searchable: true, with_user: false, affiliations: 1 },
  { first_name: "Sarah", last_name: "Davis", email: "sarah.davis@outlook.com", email_2: "sd@alt.com", searchable: true, with_user: true, affiliations: 2 }
]

test_people.each do |data|
  next if Person.where(
    "LOWER(first_name) = ? AND LOWER(last_name) = ? AND LOWER(COALESCE(email, '')) = ?",
    data[:first_name].downcase,
    data[:last_name].downcase,
    (data[:email] || "").downcase
  ).exists?

  person_attrs = {
    first_name: data[:first_name],
    last_name: data[:last_name],
    email: data[:email],
    email_2: data[:email_2],
    profile_is_searchable: data[:searchable],
    created_by: admin_user,
    updated_by: admin_user
  }

  if data[:with_user]
    user_email = data[:email] || "#{data[:first_name].downcase.gsub(' ', '')}.#{data[:last_name].downcase.gsub(' ', '')}@example.com"
    user = User.where(email: user_email).first_or_create!(
      email: user_email,
      first_name: data[:first_name],
      last_name: data[:last_name],
      password: "password",
      password_confirmation: "password",
      confirmed_at: Time.current
    )

    unless user.person.present?
      person = Person.create!(person_attrs)
      user.update!(person: person)
    end
  else
    Person.create!(person_attrs)
  end
end

# Create affiliations for test people
Person.where(
  "LOWER(last_name) IN (?)",
  %w[johnson johnston johnstone garcia garcia-lopez smith smithson williams williamson brown browning davis davidson cruz cruz-santos]
).find_each do |person|
  match = test_people.find { |d| d[:first_name] == person.first_name && d[:last_name] == person.last_name }
  next unless match
  next if match[:affiliations].zero?
  next if person.affiliations.count >= match[:affiliations]

  needed = match[:affiliations] - person.affiliations.count
  needed.times do
    org = orgs.sample
    next unless org
    next if person.affiliations.exists?(organization: org)

    title = [
      "Facilitator", "Lead Facilitator", "Co-Facilitator",
      "Assistant Facilitator", "Volunteer", "Board Member"
    ].sample
    Affiliation.create!(
      person: person,
      organization: org,
      title: title,
      position: [ :default, :liaison, :leader, :assistant ].sample,
      start_date: rand(1..5).years.ago.to_date,
      inactive: [ false, false, false, true ].sample
    )
  end
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
                  body: body_content,
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

puts "Creating StoryIdeas…"
10.times do |i|
  body_content = Faker::Lorem.paragraph(sentence_count: 10)
  StoryIdea.create!(
    body: body_content,
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

puts "Creating WorkshopIdeas…"
[
  "Creative Expression Through Collage",
  "Mindful Drawing for Healing",
  "Empowerment Through Mixed Media"
].each do |title|
  WorkshopIdea.where(title: title).first_or_create!(
    windows_type_id: WindowsType.all.sample&.id,
    created_by_id: User.first&.id,
    updated_by_id: User.first&.id,
    created_at: Time.current - rand(1..90).days,
    updated_at: Time.current - rand(1..40).days
  )
end

puts "Creating WorkshopVariationIdeas…"
[
  "Art Journaling Variation",
  "Group Mural Adaptation",
  "Outdoor Collage Variation"
].each do |name|
  workshop = Workshop.all.sample
  next unless workshop

  WorkshopVariationIdea.where(name: name, workshop_id: workshop.id).first_or_create!(
    rhino_body: "<p>#{Faker::Lorem.paragraph(sentence_count: 6)}</p>",
    permission_given: true,
    author_credit_preference: AuthorCreditable::AUTHOR_CREDIT_PREFERENCES.sample,
    organization_id: Organization.all.sample&.id,
    windows_type_id: WindowsType.all.sample&.id,
    created_by_id: User.first&.id,
    updated_by_id: User.first&.id,
    created_at: Time.current - rand(1..90).days,
    updated_at: Time.current - rand(1..40).days
  )
end

puts "Creating WorkshopLogs…"
5.times do
  workshop = Workshop.all.sample
  next unless workshop

  WorkshopLog.create!(
    workshop_id: workshop.id,
    organization_id: Organization.all.sample&.id,
    windows_type_id: WindowsType.all.sample&.id,
    created_by_id: User.first&.id,
    date: Date.today - rand(1..90).days,
    children_ongoing: rand(0..5),
    teens_ongoing: rand(0..3),
    adults_ongoing: rand(0..10),
    children_first_time: rand(0..2),
    teens_first_time: rand(0..2),
    adults_first_time: rand(0..4),
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
          body: body_content,
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


puts "Creating Events with shared forms…"
admin_user = User.find_by(email: "umberto.user@example.com")
long_form = Form.standalone.find_by!(name: ExtendedEventRegistrationFormBuilder::FORM_NAME)
short_form = Form.standalone.find_by!(name: ShortEventRegistrationFormBuilder::FORM_NAME)
scholarship_form = Form.standalone.find_by!(name: ScholarshipApplicationFormBuilder::FORM_NAME)

# Each entry: [title, form_type, cost_cents, scholarship?, visibility]
# form_type: :long, :short, or :none
dev_events = [
  [ "AWBW Facilitator Training", :long, 15_000, true,
    { published: true, featured: true, publicly_visible: true } ],
  [ "Facilitator Training: Trauma-Informed Art Practices", :long, 12_000, true,
    { published: true, featured: true } ],
  [ "A Year of Healing and Rebuilding Together Wellness Day", :short, 0, false,
    { published: true, publicly_visible: true, publicly_featured: true, featured: true } ],
  [ "Youth Creativity Day", :short, 0, false,
    { published: true, publicly_visible: true, publicly_featured: true } ],
  [ "Mindful Art for Survivors Workshop", :short, 5_000, true,
    { published: true, publicly_visible: true, publicly_featured: true } ],
  [ "Community Open Studio Night", :none, 0, false,
    { published: true, featured: true } ],
  [ "Annual Celebration of Voices", :none, 0, false,
    { published: true, publicly_visible: true } ],
  [ "Art as Healing: Virtual Group Session", :short, 0, false,
    { published: true, featured: true } ],
  [ "Leaders in Creativity: Facilitator Roundtable", :short, 0, false,
    { published: true, publicly_visible: true } ],
  [ "Family Creative Expression Day", :short, 0, false,
    { published: true, publicly_visible: true, publicly_featured: true } ],
  [ "Creative Safety & Support Workshop", :short, 2_500, true,
    { published: true, featured: true } ],
  [ "Healing Through Art: Spring Community Gathering", :short, 0, false,
    { published: true, publicly_visible: true } ]
]

dev_events.each_with_index do |(title, form_type, cost_cents, scholarship, visibility), i|
  start_date = Time.current + (5 + i * 5).days
  end_date = start_date + rand(2..4).hours
  registration_close = start_date - rand(2..7).days
  registerable = form_type != :none

  desc_content = Faker::Lorem.paragraph(sentence_count: 6)
  event = Event.find_or_create_by!(title: title) do |e|
    e.description = desc_content
    e.rhino_description = desc_content
    e.start_date = start_date
    e.end_date = end_date
    e.registration_close_date = registration_close
    e.cost_cents = cost_cents
    e.public_registration_enabled = false
    e.created_by = admin_user
    visibility.each { |k, v| e.send(:"#{k}=", v) }
  end

  if registerable
    reg_form = form_type == :long ? long_form : short_form
    EventForm.find_or_create_by!(event: event, role: "registration") do |ef|
      ef.form = reg_form
    end
    event.update!(public_registration_enabled: true) unless event.public_registration_enabled?
  end

  if scholarship
    EventForm.find_or_create_by!(event: event, role: "scholarship") do |ef|
      ef.form = scholarship_form
    end
  end
end

puts "Creating Event Registrations…"

# Key people for named scenarios
amy_person = User.find_by(email: "amy.user@example.com")&.person
maria_j = Person.find_by(first_name: "Maria", last_name: "Johnson")
anna_g = Person.find_by(first_name: "Anna", last_name: "Garcia")
sarah_s = Person.find_by(first_name: "Sarah", last_name: "Smith")
lisa_w = Person.find_by(first_name: "Lisa", last_name: "Williams")
jessica_b = Person.find_by(first_name: "Jessica", last_name: "Brown")
kim_d = Person.find_by(first_name: "Kim", last_name: "Davis")
rosa_dlc = Person.find_by(first_name: "Rosa", last_name: "De La Cruz")
mario_j = Person.find_by(first_name: "Mario", last_name: "Johnson") # no user
angel_g = Person.find_by(first_name: "Angel", last_name: "Garcia") # no user
linda_w = Person.find_by(first_name: "Linda", last_name: "Williams") # no user

# Events by name for clarity
facilitator_training = Event.find_by(title: "AWBW Facilitator Training")
trauma_training = Event.find_by(title: "Facilitator Training: Trauma-Informed Art Practices")
wellness_day = Event.find_by(title: "A Year of Healing and Rebuilding Together Wellness Day")
youth_day = Event.find_by(title: "Youth Creativity Day")
mindful_art = Event.find_by(title: "Mindful Art for Survivors Workshop")
virtual_session = Event.find_by(title: "Art as Healing: Virtual Group Session")
roundtable = Event.find_by(title: "Leaders in Creativity: Facilitator Roundtable")
family_day = Event.find_by(title: "Family Creative Expression Day")
# "Community Open Studio Night" and "Annual Celebration of Voices" have no registration forms — left with zero registrations

registrations_data = []

# --- Facilitator Training: multiple registrations from different people, extended form ---
# Amy: registered, with form submission, scholarship recipient
# Maria Johnson: registered, with form submission (has user)
# Anna Garcia: attended, with form submission (has user)
# Mario Johnson: registered, no form submission (no user)
# Kim Davis: cancelled (has user)
if facilitator_training
  [
    { person: amy_person, status: "registered", scholarship_recipient: true, scholarship_tasks_completed: false },
    { person: maria_j, status: "registered" },
    { person: anna_g, status: "attended" },
    { person: mario_j, status: "registered" },
    { person: kim_d, status: "cancelled" }
  ].each do |data|
    next unless data[:person]
    registrations_data << data.merge(event: facilitator_training)
  end
end

# --- Trauma Training: extended form, scholarship ---
# Sarah Smith: registered with form (has user)
# Jessica Brown: registered with form, scholarship (has user)
# Angel Garcia: registered, no form (no user)
# Linda Williams: no_show (no user)
if trauma_training
  [
    { person: sarah_s, status: "registered" },
    { person: jessica_b, status: "registered", scholarship_recipient: true, scholarship_tasks_completed: true },
    { person: angel_g, status: "registered" },
    { person: linda_w, status: "no_show" }
  ].each do |data|
    next unless data[:person]
    registrations_data << data.merge(event: trauma_training)
  end
end

# --- Amy registered to multiple events (person registered across events) ---
if amy_person
  [ wellness_day, mindful_art, virtual_session ].compact.each do |evt|
    registrations_data << { person: amy_person, event: evt, status: "registered" }
  end
end

# --- Maria Johnson also registered to multiple events ---
if maria_j
  [ wellness_day, youth_day ].compact.each do |evt|
    registrations_data << { person: maria_j, event: evt, status: "registered" }
  end
end

# --- Rosa De La Cruz registered to a couple events (has user) ---
if rosa_dlc
  [ wellness_day, family_day ].compact.each do |evt|
    registrations_data << { person: rosa_dlc, event: evt, status: "registered" }
  end
end

# --- Lisa Williams: incomplete_attendance on one event ---
if lisa_w && roundtable
  registrations_data << { person: lisa_w, event: roundtable, status: "incomplete_attendance" }
end

# --- People with multiple active affiliations — ensures org snapshots get exercised ---
mariana_j = Person.find_by(first_name: "Mariana", last_name: "Johnson")
samuel_s = Person.find_by(first_name: "Samuel", last_name: "Smith")
lisa_wn = Person.find_by(first_name: "Lisa", last_name: "Williamson")
kim_dv = Person.find_by(first_name: "Kim", last_name: "Davidson")
sarah_d = Person.find_by(first_name: "Sarah", last_name: "Davis")

{ mariana_j => youth_day, samuel_s => mindful_art, lisa_wn => virtual_session,
  kim_dv => family_day, sarah_d => roundtable }.each do |person, evt|
  next unless person && evt
  registrations_data << { person: person, event: evt, status: "registered" }
end

# --- Wellness Day gets extra registrations (popular free event, short form) ---
if wellness_day
  [ sarah_s, jessica_b, lisa_w, kim_d ].compact.each do |person|
    registrations_data << { person: person, event: wellness_day, status: "registered" }
  end
end

# Create all registrations
registrations_data.each do |data|
  next unless data[:event] && data[:person]
  next if EventRegistration.exists?(event: data[:event], registrant: data[:person])

  EventRegistration.create!(
    event: data[:event],
    registrant: data[:person],
    status: data[:status] || "registered",
    scholarship_recipient: data[:scholarship_recipient] || false,
    scholarship_tasks_completed: data[:scholarship_tasks_completed] || false,
    scholarship_requested: data[:scholarship_recipient] || false
  )
end

puts "Creating Registration Form Submissions…"
# Create person_form records linking registrants to their event's registration form.
# This simulates people who filled out the registration form.
form_submissions = []

# Facilitator Training (extended form) — some registrants filled it out, one didn't
if facilitator_training
  reg_form = facilitator_training.registration_form
  if reg_form
    # People with users who filled out the form
    [ amy_person, maria_j, anna_g ].compact.each do |person|
      form_submissions << { person: person, form: reg_form }
    end
    # Mario Johnson (no user) did NOT fill out the form — registration without form submission
  end

  # Amy also filled out the scholarship form
  scholarship_f = facilitator_training.scholarship_form
  if scholarship_f && amy_person
    form_submissions << { person: amy_person, form: scholarship_f }
  end
end

# Trauma Training (extended form)
if trauma_training
  reg_form = trauma_training.registration_form
  if reg_form
    # Sarah Smith (has user) and Jessica Brown (has user) filled out forms
    [ sarah_s, jessica_b ].compact.each do |person|
      form_submissions << { person: person, form: reg_form }
    end
    # Angel Garcia (no user) filled out the form — person without user + form
    form_submissions << { person: angel_g, form: reg_form } if angel_g
    # Linda Williams (no user) did NOT fill out the form
  end

  # Jessica filled out the scholarship form
  scholarship_f = trauma_training.scholarship_form
  if scholarship_f && jessica_b
    form_submissions << { person: jessica_b, form: scholarship_f }
  end
end

# Wellness Day (short form) — most filled it out
if wellness_day
  reg_form = wellness_day.registration_form
  if reg_form
    # People with users
    [ amy_person, maria_j, sarah_s, jessica_b, kim_d ].compact.each do |person|
      form_submissions << { person: person, form: reg_form }
    end
    # Rosa (has user) filled it out too
    form_submissions << { person: rosa_dlc, form: reg_form } if rosa_dlc
    # Lisa Williams (has user) registered but didn't fill out the form — person with user + no form
  end
end

# Mindful Art (short form, has scholarship) — Amy filled out both
if mindful_art
  reg_form = mindful_art.registration_form
  form_submissions << { person: amy_person, form: reg_form } if reg_form && amy_person

  scholarship_f = mindful_art.scholarship_form
  form_submissions << { person: amy_person, form: scholarship_f } if scholarship_f && amy_person
end

# Youth Day (short form) — Maria filled it out
if youth_day
  reg_form = youth_day.registration_form
  form_submissions << { person: maria_j, form: reg_form } if reg_form && maria_j
end

# Virtual Session (short form) — Amy (has user) registered but no form submission — person with user + no form
# Family Day (short form) — Rosa filled it out
if family_day
  reg_form = family_day.registration_form
  form_submissions << { person: rosa_dlc, form: reg_form } if reg_form && rosa_dlc
end

# Create all form submissions with sample field responses
form_submissions.each do |data|
  next unless data[:person] && data[:form]
  next if PersonForm.exists?(person: data[:person], form: data[:form])

  pf = PersonForm.create!(person: data[:person], form: data[:form])

  # Fill in required text fields with sample data
  data[:form].form_fields.where(answer_type: [ :free_form_input_one_line, :free_form_input_paragraph ]).each do |field|
    sample_text = case field.field_key
    when "first_name" then data[:person].first_name
    when "last_name" then data[:person].last_name
    when "primary_email", "enter_email", "confirm_email" then data[:person].preferred_email || "sample@example.com"
    when "phone" then "(555) #{rand(100..999)}-#{rand(1000..9999)}"
    when "street_address", "agency_street_address" then Faker::Address.street_address
    when "city", "agency_city" then Faker::Address.city
    when "state_province", "agency_state_province" then Faker::Address.state_abbr
    when "zip_postal_code", "agency_zip_postal_code" then Faker::Address.zip_code
    when "agency_organization_name" then Faker::Company.name
    when "position_title" then "Facilitator"
    when "agency_website" then "https://example.org"
    when "racial_ethnic_identity" then "Prefer not to say"
    when "secondary_email" then data[:person].email_2
    when "preferred_nickname" then data[:person].first_name
    when "pronouns" then [ "she/her", "he/him", "they/them" ].sample
    else
      if field.answer_type == "free_form_input_paragraph"
        Faker::Lorem.paragraph(sentence_count: 3)
      else
        Faker::Lorem.word.capitalize
      end
    end

    PersonFormFormField.create!(
      person_form: pf,
      form_field: field,
      text: sample_text.to_s
    )
  end
end

puts "Creating Resources…"
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

  resource_body = Faker::Lorem.paragraph(sentence_count: 8)
  Resource.where(title: Faker::Book.title).first_or_create!(
    body: resource_body,
    rhino_body: resource_body,
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
We welcome you to implement the <a href="/awbw/programs-adult_windows.phjp">Adult Windows Program</a> or the <a href="/awbw/programs-youth_windows">Youth Windows Program</a> at your organization. AWBW provides a comprehensive two-day training program for new leaders at our office/studio in Venice, California, or in <a href="/awbw/programs-training_locations.php">other locations nationwide</a> (make this a link for non-local trainings?). Our training, facilitated by artists and experienced leaders, prepares you to bring the Windows Program to your organization. In some cases, we are also able to provide art supply allowances to help you get started. For all organizations that begin a Windows Program, AWBW provides permanent ongoing support including newsletters, leader's workshops, access to online leader support, and personalized consultation for as long as your program exists. Check for <a href="/awbw/programs-training.php">upcoming training opportunities</a>.
    ), published: true, ordering: 170
  },
  {
    id: 6, question: "How can I volunteer for A Window Between Worlds?",
    answer: %(
<a href="/awbw/contact.php">Contact us</a>! We have a wide variety of <a href="/awbw/volunteer.php">volunteer opportunities</a> for anyone who is available to donate some time in the Los Angeles area.
    ), published: true, ordering: 165
  },
  {
    id: 7, question: "I am a survivor. How can I participate in the art program?",
    answer: %(
You are welcome to participate in our <a href="/awbw/programs-sac.php">Survivor's Art Circle</a>, which provides support and encouragement for any domestic violence survivor wishing to use art as a healing tool. If you are in the Los Angeles area, you can attend monthly hands-on workshops with other survivors. If you are not in Los Angeles, you are welcome to participate in the online community of support. As part of the Survivor's Art Circle you will receive a monthly newsflash, and will be welcome to participate in group project ideas you can complete at home. You will also be welcome to participate in Survivor's Art Circle exhibition opportunities.
    ), published: true, publicly_visible: true, ordering: 140
  },
  {
    id: 12, question: "How do I get a scholarship for Leadership Training?",
    answer: %(
We award all scholarships based on need and availability of funds to agencies serving domestic violence clients. We ask those interested in applying for scholarship funding to submit a <a href="/awbw/programs-leadership_training-scholarships_application.php">Scholarship Request</a> 4 weeks in advance of the chosen training. <a href="/awbw/programs-leadership_training-scholarships.php">Click here</a> to see the guidelines.
    ), published: true, ordering: 120
  },
  {
    id: 13, question: "I need more art supplies to hold my Windows Workshops. How can AWBW help?",
    answer: %(
AWBW awards Art Supply Scholarships to active reporting programs. All scholarship grants are based on need, availability of funds and strength of monthly reporting. Programs must report for a minimum of three months to be eligible to receive an art supply scholarship and must continue to hold weekly workshops and report monthly for a period of one year.<br /><br />AWBW programs that have been awarded art supply scholarships will be reimbursed for art supplies bought at any purveyor of their choosing as long as they submit receipts attached to AWBW's reimbursement form.<br /><br />Visit our <a href="/awbw/programs-women_windows-art_supplies.php">recommended supply resource list</a> for information on where you can order art supplies.<br /><br />AWBW also offers some free art supplies from our donated goods shopping area. Programs in good standing can make an appointment to "free shop" at our Venice location.
    ), published: true, ordering: 110
  },
  {
    id: 5, question: "I would like to volunteer to run art workshops at my local shelter. How can I get involved?",
    answer: %(
Due to confidentiality issues, art workshops are run by volunteers and staff who already work with a domestic violence agency, rather than outside volunteers. Contact your local domestic violence organization to find out about volunteer opportunities and whether or not they use the Windows Program. You will need to meet the individual agency's training requirements and get their permission and support to implement AWBW's program. Resource numbers you can call to find <a href="/awbw/contact-dv_resources.php">domestic violence organizations in your local area</a>.
    ), published: true, ordering: 109
  },
  {
    id: 38, question: "Why Can We Train People Within Our Agency, But Not Train People Outside Our Agency?",
    answer: %(
1. We encourage you to train others within your agency because we want you to be able to do all you can to help your Windows groups become as strong and creative as possible. Over the years we've seen that the AWBW trained leaders can teach others quite effectively, and the new leaders they train also become a wonderful asset to the program.<br />
2. There is a special process for training the trainers (for training beyond one's own agency). Otherwise many people who've been to only one training might want to start representing AWBW, and leading throughout beyond their agency, and we'd have no way of knowing if they were effective. There would also be no system of connecting what they are doing into the AWBW network of leaders. <br />
3. Everything we do has been made possible by the network of leaders communicating and staying in touch with AWBW. The program and all that's been developed simply wouldn't exist without all the leaders sending their reports, insights and thoughts to AWBW so we can share them with everybody. So by leading the trainings we are able to make sure new agencies get the best shot possible at being closely connected to this network, so that it can thrive and continue.
    ), published: true, ordering: 108
  },
  {
    id: 39, question: "So How Can I Share AWBW With Other Agencies Within My Community?",
    answer: %(
These are some ways you can help other agencies start their own Windows Programs:<br />
1. Share an introductory workshop with them (rather than a full training). Be sure to let us know you are doing it. That way we can help you pick a workshop to lead (if you want help) and we can give you the Workshop Feedback form to pass out. The form gives participants a way to get in touch with us so we can help them get further training so desire.<br />
2. Encourage them to get trained (by either hosting a training, having distance learning, or coming to California :-)<br />
3. Encourage them to take advantage of the scholarships we have through grant funding for the training in LA and the distance training.<br />
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
    body: "A step-by-step guide to preparing and leading your first AWBW workshop.",
    youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
    published: true,
    featured: true,
    publicly_visible: true,
    publicly_featured: true,
    position: 1
  },
  {
    title: "Trauma-Informed Facilitation Basics",
    body: "Learn the foundations of trauma-informed facilitation for art-based healing workshops.",
    youtube_url: "https://www.youtube.com/watch?v=jNQXAC9IVRw",
    published: true,
    featured: true,
    publicly_visible: true,
    publicly_featured: true,
    position: 2
  },
  {
    title: "Creating Safe Spaces for Art Expression",
    body: "How to set up your workshop environment to foster safety, trust, and creative expression.",
    youtube_url: "https://www.youtube.com/watch?v=9bZkp7q19f0",
    published: true,
    featured: true,
    publicly_visible: true,
    publicly_featured: true,
    position: 3
  },
  {
    title: "Working with Children and Youth",
    body: "Techniques and tips for adapting workshops for younger participants.",
    youtube_url: "https://www.youtube.com/watch?v=kJQP7kiw5Fk",
    published: true,
    featured: true,
    position: 4
  },
  {
    title: "Art Materials and Supply Management",
    body: "A practical guide to choosing, organizing, and budgeting for art supplies.",
    youtube_url: "https://www.youtube.com/watch?v=RgKAFK5djSk",
    published: true,
    featured: true,
    position: 5
  },
  {
    title: "Monthly Reporting Walkthrough",
    body: "How to complete your monthly reports and share workshop outcomes with AWBW.",
    youtube_url: "https://www.youtube.com/watch?v=JGwWNGJdvx8",
    published: true,
    featured: true,
    position: 6
  }
].each do |tutorial_data|
  Tutorial.where(title: tutorial_data[:title]).first_or_create!(tutorial_data)
end

puts "Creating Bookmarks for seed users…"
amy = User.find_by(email: "amy.user@example.com")
priya = User.find_by(email: "priya.user@example.com")

if amy && priya
  excluded_person_ids = [ amy.person_id, priya.person_id ].compact

  # Two records per bookmarkable type (where available)
  pairs = {
    "CommunityNews"        => CommunityNews.order(:id).limit(2).to_a,
    "Event"                => Event.order(:id).limit(2).to_a,
    "Organization"         => Organization.order(:id).limit(2).to_a,
    "Person"               => Person.where.not(id: excluded_person_ids).order(:id).limit(2).to_a,
    "Report"               => Report.order(:id).limit(2).to_a,
    "Resource"             => Resource.order(:id).limit(2).to_a,
    "Story"                => Story.order(:id).limit(2).to_a,
    "StoryIdea"            => StoryIdea.order(:id).limit(2).to_a,
    "Tutorial"             => Tutorial.order(:id).limit(2).to_a,
    "Workshop"             => Workshop.order(:id).limit(2).to_a,
    "WorkshopIdea"         => WorkshopIdea.order(:id).limit(2).to_a,
    "WorkshopLog"          => WorkshopLog.order(:id).limit(2).to_a,
    "WorkshopVariation"    => WorkshopVariation.order(:id).limit(2).to_a,
    "WorkshopVariationIdea" => WorkshopVariationIdea.order(:id).limit(2).to_a
  }.reject { |_, v| v.empty? }

  # 3 types are shared between Amy and Priya for tally testing
  shared_types = pairs.keys.first(3)

  pairs.each do |type, records|
    if shared_types.include?(type)
      # Both users bookmark the first record
      [ amy, priya ].each { |u| u.bookmarks.find_or_create_by!(bookmarkable: records.first) }
    else
      # Each user gets a different record (Priya falls back to first if only one exists)
      amy.bookmarks.find_or_create_by!(bookmarkable: records.first)
      priya.bookmarks.find_or_create_by!(bookmarkable: records.last)
    end
  end

  puts "  Created #{amy.bookmarks.count} bookmarks for Amy, #{priya.bookmarks.count} for Priya"
  shared = amy.bookmarks.pluck(:bookmarkable_type, :bookmarkable_id) &
           priya.bookmarks.pluck(:bookmarkable_type, :bookmarkable_id)
  puts "  #{shared.size} bookmarks shared between both users"
end
