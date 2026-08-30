class ContactUsMailerPreview < ActionMailer::Preview
  def hello
    contact_us = {
      q: "general",
      subject: "Test Subject",
      from: "test@example.com",
      first_name: "John",
      last_name: "Doe",
      organization: "Test Organization",
      message: "This is a test message"
    }
    ContactUsMailer.hello(contact_us)
  end
end
