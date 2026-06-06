# Workshop seeds (dev-only) - run on their own via `rake db:seed:workshops`, or
# as part of `rake db:seed:dev`. Covers workshops (including duplicate-title
# variants), their category/sector assignments, and workshop variations.

adult_wt = WindowsType.find_by!(short_name: "Adult")
children_wt = WindowsType.find_by!(short_name: "Children")
combined_wt = WindowsType.find_by!(short_name: "Combined")

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
    publicly_visible: true,
    publicly_featured: true,
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
    publicly_visible: true,
    publicly_featured: true,
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

# Duplicate-title workshops to exercise ID disambiguation in search
# Covers: same title/author/type (true dupes), same title/different author, same title/different type
[
  # Same title, same author, same windows type (true dupes — different years)
  { title: "Healing Through Color", full_name: "Maria Torres", windows_type: adult_wt,
    month: 3, year: 2020,
    description: "Uses color mixing and painting to help participants explore emotions and find calm.",
    published: true, searchable: true, created_by: admin_user },
  { title: "Healing Through Color", full_name: "Maria Torres", windows_type: adult_wt,
    month: 6, year: 2024,
    description: "Revised edition with new guided prompts for exploring emotions through color.",
    published: true, searchable: true, created_by: admin_user },
  # Same title, different author, same windows type
  { title: "Healing Through Color", full_name: "James Whitfield", windows_type: adult_wt,
    month: 9, year: 2022,
    description: "A revised version exploring color as a pathway to emotional awareness.",
    published: true, searchable: true, created_by: admin_user },
  # Same title, same author, different windows type
  { title: "Healing Through Color", full_name: "Maria Torres", windows_type: children_wt,
    month: 1, year: 2023,
    description: "Adapted for children: color mixing and painting to explore emotions through play.",
    published: true, searchable: true, created_by: admin_user },
  # Same title as existing seed workshop, different author and windows type
  { title: "Inspirational Scrolls", full_name: "Linda Park", windows_type: combined_wt,
    month: 5, year: 2021,
    description: "A combined-audience version of Inspirational Scrolls for mixed-age groups.",
    published: true, searchable: true, created_by: admin_user },
  # Same title as existing, same author, same type (true dupe)
  { title: "Feelings Collages", full_name: "Lisa Cohen", windows_type: adult_wt,
    month: 11, year: 2019,
    description: "Updated edition with new collage prompts exploring a wider range of emotions.",
    published: true, searchable: true, created_by: admin_user }
].each do |workshop_data|
  Workshop.where(title: workshop_data[:title], full_name: workshop_data[:full_name],
                 windows_type: workshop_data[:windows_type], year: workshop_data[:year])
          .first_or_create!(workshop_data)
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

  windows_type_id = [ adult_wt.id, children_wt.id, combined_wt.id ].sample
  variation = workshop.workshop_variations.find_or_initialize_by(name: var_data[:name])
  variation.assign_attributes(
    body: var_data[:rhino_body],
    rhino_body: var_data[:rhino_body],
    position: var_data[:position],
    published: [ true, true, false ].sample,
    windows_type_id: windows_type_id,
    author_credit_preference: "anonymous"
  )
  variation.save!
end
