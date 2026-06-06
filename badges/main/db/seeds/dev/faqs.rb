# FAQ seeds (dev-only) - run on their own via `rake db:seed:faqs`, or as part of
# `rake db:seed:dev`.

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
We award all scholarships based on need and avaishability of funds to agencies serving domestic violence clients. We ask those interested in applying for scholarship funding to submit a <a href="/awbw/programs-leadership_training-scholarships_application.php">Scholarship Request</a> 4 weeks in advance of the chosen training. <a href="/awbw/programs-leadership_training-scholarships.php">Click here</a> to see the guidelines.
    ), published: true, ordering: 120
  },
  {
    id: 13, question: "I need more art supplies to hold my Windows Workshops. How can AWBW help?",
    answer: %(
AWBW awards Art Supply Scholarships to active reporting programs. All scholarship grants are based on need, avaishability of funds and strength of monthly reporting. Programs must report for a minimum of three months to be eligible to receive an art supply scholarship and must continue to hold weekly workshops and report monthly for a period of one year.<br /><br />AWBW programs that have been awarded art supply scholarships will be reimbursed for art supplies bought at any purveyor of their choosing as long as they submit receipts attached to AWBW's reimbursement form.<br /><br />Visit our <a href="/awbw/programs-women_windows-art_supplies.php">recommended supply resource list</a> for information on where you can order art supplies.<br /><br />AWBW also offers some free art supplies from our donated goods shopping area. Programs in good standing can make an appointment to "free shop" at our Venice location.
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
