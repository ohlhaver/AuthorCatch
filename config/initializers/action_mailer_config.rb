ActionMailer::Base.smtp_settings = {
    :address => "smtp.emailsrvr.com",
    :port => "25",
    :domain => "jurnalo.com",
    :authentication => :plain,
    :user_name => "no-reply@jurnalo.com",
    :password => "it7janze" 
}