# Quote seeds (dev-only) - run on their own via `rake db:seed:quotes`, or as part
# of `rake db:seed:dev`. Also links quotes to seed workshops when those workshops
# are present (e.g. after `rake db:seed:workshops`).

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

# Linking only makes sense once workshops exist (e.g. after db:seed:workshops);
# when run on its own with no workshops, just seed the quotes above and skip.
seed_quotes.each_with_index do |quote, i|
  next if seed_workshops.empty?

  workshop = seed_workshops[i % seed_workshops.size]
  next unless workshop

  QuotableItemQuote.find_or_create_by!(
    quotable: workshop,
    quote: quote
  )
end
