# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.4' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')
gem('curb')
require 'curb'
Curl::Multi.default_timeout = 100 # 100 milliseconds 

Rails::Initializer.run do |config|
  
  gem( "japi", :version => '>=1.2.0' )
  require 'JAPI'
  
  JAPI.rails_init( RAILS_ENV, RAILS_ROOT, 1, '/config/japi.yml' )
  #
  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Specify gems that this application depends on and have them installed with rake gems:install
  # config.gem "bj"
  # config.gem 'erubis' , :version => '>=2.6.4'
  # config.gem 'erubis_rails_helper', :version => '1.0.0'
  config.gem 'nokogiri'
  ActiveSupport::XmlMini.backend = 'NokogiriSAX'
  
  # Only load the plugins named here, in the order given (default is alphabetical).
  # :all can be used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

  # Skip frameworks you're not going to use. To use Rails without a database,
  # you must remove the Active Record framework.
  config.frameworks -= [ :active_record ]

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

  # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
  # Run "rake -D time" for a list of tasks for finding time zone names.
  config.time_zone = 'UTC'

  # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
  # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}')]
  # config.i18n.default_locale = :de
end

ExceptionNotification::Notifier.exception_recipients = %w(ram@rforce.in ohlhaver@gmail.com)
ExceptionNotification::Notifier.sender_address = %(no-reply@jurnalo.com)

Rails.logger.info( "Rails Initialized" )
JAPI::PreferenceOption.async_load_all

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      Rails.logger.info( 'Passenger Forked' )
      JAPI::Model::Base.client = JAPI::Client.new( JAPI::Config[:client] )
      TICKET_STORE.reset if TICKET_STORE
      memcache = Rails.cache.instance_variable_get('@data')
      memcache.reset if memcache.respond_to?( :reset )
    end
  end
end