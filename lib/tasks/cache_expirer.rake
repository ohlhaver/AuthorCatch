namespace :www do
  
  desc "Expires the cache for non logged in users and generate a new cache"
  task :expire_home_cache do
    editions = [ 'int-en', 'de-de', 'at-de', 'ch-de', 'in-en', 'gb-en', 'us-en' ]
    locales = [ 'de', 'en' ]
    editions.each do |edition|
      locales.each do |locale|
        system( "curl --silent -A \"CE Jurnalo Robot\" \"http://www.jurnalo.com/?edition=#{edition}&locale=#{locale}&exec=9999\" > /dev/null" )
        puts "Refreshed #{edition}-#{locale} home."
      end
    end
  end
  
end