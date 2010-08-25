# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.

ActionController::Base.session = {
  :domain       => ( RAILS_ENV != 'production' ? nil : '.authorcatch.com' ),
  :key          => '_af',
  :secret       => 'e9288eecc6d3b1ac534cdb05c3b45bb234a5fb1241bd5d510e1df2229874c42fdf9874e5f726c80379abfabfdc65b58929129b2cae14a0c936f0f5d5939a64b5',
  :expire_after => 30.days
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
JTicketStoreConfig = YAML.load_file( "#{RAILS_ROOT}/config/tickets.yml" )

unless JTicketStoreConfig[RAILS_ENV]['servers'].blank?
  require 'memcache'
  TICKET_STORE = MemCache.new( JTicketStoreConfig[RAILS_ENV]['servers'], :multithread => true )
else
  TICKET_STORE = nil
end