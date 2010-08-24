JAPI::Client.class_eval do
  
  def async_api_call( path, multi_curb, params = {}, &block )
    params ||= {}
    async_api_response( path, multi_curb, params ) do |response|
      result = ( Hash.from_xml( response ) rescue nil ).try( :[], 'response' )
      result ||= Hash.from_xml( incorrect_format_api_call_response( path ) )[ 'response' ]
      result.symbolize_keys!
      objectify_result_data!( result )
      block.call( result )
    end
  end
  
  def async_api_response( path, multi_curb, params, &block )
    url = URI.parse( api_request_url( path ) )
    request = Net::HTTP::Post.new( url.path )
    flatten_params!( params )
    request.set_form_data( params )
    Curb.async_post( url.to_s, request.body, :multi_curb => multi_curb, :timeout => 6*(self.timeout||10), :catch_errors => true ) do |response|
      xml = response.body_str if response
      xml ||= invalid_api_call_response( path )
      block.call( xml )
    end
    return true
  end
  
  def api_response( path, params )
    url = URI.parse( api_request_url( path ) )
    request = Net::HTTP::Post.new( url.path )
    # Multiple Params Fix
    flatten_params!( params )
    request.set_form_data( params )
    response = Curb.post( url.to_s, request.body, :timeout => 6*(self.timeout||10), :catch_errors => true)
    return response.body_str if response
    return invalid_api_call_response( path )
    # Timeout::timeout( self.timeout ) {
    #   response = Net::HTTP.new( url.host, url.port ).start{ |http| http.request( request ) } rescue nil
    #   return response.try( :body ) || invalid_api_call_response( path )
    # }
    # return timeout_api_call_response( path )
  end
  
end

JAPI::Model::Base.class_eval do
  
  attr_reader :multi_curb
  
  def set_multi_curb
    @multi_curb = Curl::Multi.new
  end
  
  def self.async_find(*arguments, &block)
    scope   = arguments.slice!(0)
    options = arguments.slice!(0) || {}
    options[:multi_curb] ||= Curl::Multi.new
    case scope
    when :all   then async_find_every(:all, options, &block)
    when :first then async_find_every(:first, options, &block)
    when :last  then async_find_every(:last, options, &block)
    when :one   then async_find_one(options, &block)
    else             async_find_single(scope, options, &block)
    end
    return options[:multi_curb]
  end
  
  
  protected
  
  def self.async_find_single( id, options={}, &block )
    options[:params] ||= {}
    options[:params].symbolize_keys!
    options[:params].merge!( :id => id )
    client.async_api_call( element_path, options[:multi_curb], options[:params] ) do |result|
      object = result[:error] ? nil : result[:data]
      object.try( :tap ){ |r| 
        r.prefix_options = { :user_id => options[:params][:user_id] } if options[:params][:user_id]
        r.pagination = result[:pagination]; 
        r.facets = result[:facets] 
      }
      block.call( object ) if block
    end
  end
  
  def self.async_find_every(item, options, &block)
    options[:params] ||= {}
    collection_block = Proc.new{ |result| 
      collection = JAPI::PaginatedCollection.new( result ).each{ |x| 
        x.prefix_options = { :user_id => options[:params][:user_id] } if options[:params][:user_id]
        x 
      }
      block.call( item == :all ? collection : collection.send( item ) ) if block
    }
    case from = options[:from]
    when Symbol :
      client.async_api_call( "#{collection_path}/#{from}", options[:multi_curb], options[:params], &collection_block )
    when String :
      client.async_api_call( from, options[:multi_curb], options[:params], &collection_block )
    else
      client.async_api_call( collection_path, options[:multi_curb], options[:params], &collection_block )
    end
  end
  
  # Find a single resource from a one-off URL
  def self.async_find_one(options, &block)
    options[:params] ||= {}
    object_block = Proc.new{ |result|
      object = result[:error] ? nil : Array( result[:data] ).first 
      object.try( :tap ){ |r| 
        r.prefix_options = { :user_id => options[:params][:user_id] } if options[:params][:user_id]
        r.pagination = result[:pagination]
        r.facets = result[:facets]
      }
      block.call( object ) if block
    }
    case( from = options[:from] )
    when Symbol :
      client.async_api_call( "#{collection_path}/#{from}", options[:multi_curb], options[:params], &object_block )
    when String :
      client.async_api_call( from, options[:params], options[:multi_curb], &object_block )
    else
      client.async_api_call( collection_path, options[:multi_curb], options[:params], &object_block )
    end
  end
  
end

JAPI::Preference.class_eval do
  fields :updated_at
end

JAPI::PreferenceOption.class_eval do 
  
  def self.edition_options
    @@edition_options ||= nil
    @@edition_options = nil if @@edition_options.try( :error )
    @@edition_options = find( :all, :params => { :preference_id => 'edition_id' } ).freeze
    @@edition_options
  end

  def self.edition_country_map
    @@edition_country_map ||= nil
    @@edition_country_map = nil if @@edition_country_map.try(:empty?)
    @@edition_country_map ||= self.edition_options.inject( {} ){ |map,record| map[ record.code.to_s.downcase ] = record.id; map }.freeze
  end
  
  def self.cluster_group_options( edition )
    @@cluster_group_options ||= {}
    hash_key = "#{edition.region}_#{edition.locale}"
    section_options = @@cluster_group_options[ hash_key ]
    @@cluster_group_options.delete( hash_key ) if section_options.try( :error )
    @@cluster_group_options[ hash_key ] ||= find( :all, :params => { :preference_id => :homepage_cluster_groups, :region_id => edition.region_id, :language_id => edition.locale_id } )
  end
  
  def self.homepage_display_options
    @@home_display_options ||= nil
    @@home_display_options = nil if @@home_display_options.try( :error )
    @@home_display_options ||= find( :all, :params => { :preference_id => :homepage_boxes } ).freeze
  end
  
  def self.cluster_sort_criteria_options
    @@cluster_sort_criteria_options ||= nil
    @@cluster_sort_criteria_options = nil if @@cluster_sort_criteria_options.try( :error )
    @@cluster_sort_criteria_options ||= sort_criteria_options.dup.delete_if{ |k| k.code.to_s =~ /_clustered$/ }
  end
  
  def self.sort_criteria_options
    @@sort_criteria_options ||= nil
    @@sort_criteria_options = nil if @@sort_criteria_options.try( :error )
    @@sort_criteria_options ||= find( :all, :params => { :preference_id => 'sort_criteria' } ).delete_if{ |k| k.code.to_s =~ /_clustered$/ }.freeze
    @@sort_criteria_options
  end
  
  def self.homepage_display_id( code )
    self.homepage_display_options.select{ |x| x.code == code.to_sym }.collect{ |x| x.id }.first
  end
  
  def self.default_country_edition( country_code )
    country_code.try(:downcase!)
    edition_country_map[ country_code ] || 'int-en'
  end
  
  def self.async_load_all
    @@clusters_group_options ||= {}
    return unless @@clusters_group_options == {}
    multi_curb = Curl::Multi.new
    prefs = { :category_id => :category, :time_span => :time_span, 
      :blog => :blog_pref, :video => :video_pref, :opinion => :opinion_pref, 
      :author => :author_rating, :source => :source_rating,
      :sort_criteria => :sort_criteria, :region_id => :region,
      :language_id => :language, :subscription_type => :subscription_type }
    prefs.each do |pref, name|  
      async_find( :all, :params => { :preference_id => pref }, :multi_curb => multi_curb ) do | result |
        class_variable_set( "@@#{ name }_options", result.freeze )
      end
    end
    multi_curb.perform
    [ 'int-en', 'in-en', 'gb-en', 'us-en', 'de-de', 'at-de', 'ch-de' ].each do |edition|
      edition = JAPI::PreferenceOption.parse_edition( edition )
      hash_key = "#{edition.region}_#{edition.locale}"
      async_find( :all, :params => { :preference_id => :homepage_cluster_groups, :region_id => edition.region_id, :language_id => edition.locale_id }, :multi_curb => multi_curb ) do |object|
        @@clusters_group_options[ hash_key ] = object
      end
    end
    multi_curb.perform
  end
  
end

JAPI::ClusterGroup.class_eval do
  
  fields :clusters, :stories
  
  def opinions?
    clusters.nil? && stories.is_a?( Array )
  end
  
end

JAPI::Cluster.class_eval do
  
  def top_keywords_in_ascii
    top_keywords.collect{ |x| x.to_ascii_s }
  end
  
  def to_param
    "#{id}-#{top_keywords_in_ascii.join('-').gsub(/\.|\ /, '-').gsub(/[^\w\-]/, '')}"
  end
  
end

JAPI::Author.class_eval do
  
  fields :average_user_preference, :user_preference_count
  
  def to_param
    "#{id}-#{name.to_ascii_s.downcase.gsub(/\.|\ /, '-').gsub(/[^\w\-]/, '')}"
  end
  
end

JAPI::Source.class_eval do
  
  fields :average_user_preference, :user_preference_count
  
  def to_param
    "#{id}-#{name.to_ascii_s.downcase.gsub(/\.|\ /, '-').gsub(/\.|\ /, '-').gsub(/[^\w\-]/, '')}"
  end
  
end

JAPI::Story.class_eval do
  
  fields :cluster, :is_opinion, :is_video, :is_blog, :reading_list_id
  
end

JAPI::Topic.class_eval do
  
  def self.async_home_count_map( multi_curb, topic_preferences, prefix_options, default_time_span, &block )
    topic_preferences.each do |pref|
      time_span = pref.time_span || default_time_span
      time_span = 24.hours.to_i if time_span.nil? || time_span.to_i > 24.hours.to_i
      async_find( :one, :multi_curb => multi_curb, :params => prefix_options.merge( :topic_id => pref.id, :time_span => time_span, :per_page => 0 ) ) do |object|
        block.call( object ) if block
      end
    end
  end
  
  
  def self.home_count_map( topic_preferences, prefix_options, default_time_span )
    multi_curb = Curl::Multi.new
    counts_map = {}
    topic_preferences.each do |pref|
      time_span = pref.time_span || default_time_span
      time_span = 24.hours.to_i if time_span.nil? || time_span.to_i > 24.hours.to_i
      async_find( :one, :multi_curb => multi_curb, :params => prefix_options.merge( :topic_id => pref.id, :time_span => time_span, :per_page => 0 ) ) do |object|
        counts_map[ pref.id ] = object
      end
    end
    multi_curb.perform
    counts_map
  end
  
  # Last 24 hours
  def home_count( time_span )
    time_span = 24.hours.to_i if time_span.nil? || time_span.to_i > 24.hours.to_i
    result = self.class.find( :one, :params => self.prefix_options.merge( :topic_id => self.id, :time_span => time_span, :per_page => 0 ) )
    #result.facets.count
    result
  end
  
  def count
    facets.try(:count) || 0
  end
  
  # used only with home_count
  def name_with_count
    facets.count > 0 ? "#{name} (#{ facets.count })" : name
  end
  
end

JAPI::TopicPreference.class_eval do
  
  attr_accessor :author, :source
  
  def self.map
    @@map ||= {
      :search_any => :qa,
      :search_all => :q,
      :search_exact_phrase => :qe,
      :search_except => :qn,
      :sort_criteria => :sc,
      :time_span => :ts,
      :subscription_type => :st,
      :blog => :bp,
      :video => :vp,
      :opinion => :op,
      :author_id => :aid,
      :source_id => :sid,
      :category_id => :cid,
      :region_id => :rid
    }
  end
  
  # from topic -> advance_search
  def self.normalize!( params = {})
    map.each{ |k,v|
      value = params.delete( k )
      params[v] = value unless value.blank?
    }
    params
  end
  
  def parse_auto_complete_params!( params = {} )
    self.author_id = params[:topic][:author_id] if params[:topic] && params[:topic][:author_id]
    self.source_id = params[:topic][:source_id] if params[:topics] && params[:topic][:source_id]
    self.author = JAPI::Author.new( :name => params[:author][:name] ) if self.author_id && params[:author] && !params[:author][:name].blank?
    self.source = JAPI::Source.new( :name => params[:source][:name] ) if self.source_id && params[:source] && !params[:source][:name].blank?
    self
  end
  
end

JAPI::Author.class_eval do
  
  def original_name
    attributes[:name]
  end
  
  def name
    join_words( words_array, 4 )
  end
  
  def full_name
    join_words( words_array )
  end
  
  protected
  
  def words_array
    words = original_name.mb_chars.split(' ')
    words.collect{ |w| w[0,1] == '"' ? w[0,1]+w[1..-1].capitalize! : w.capitalize }
  end
  
  def join_words( words, count = nil )
    count && words.size > count ? words[0, count].push('...').join(' ') : words.join(' ')
  end
  
end


JAPI::User.class_eval do
  
  attr_accessor :home_blocks
  attr_accessor :home_blocks_order
  attr_accessor :navigation_links
  attr_accessor :topic_preferences
  attr_accessor :preference
  attr_accessor :section_preferences
  
  self.session_revalidation_timeout = 24.hours
  
  def set_preference
    @preference ||= JAPI::Preference.find( id_or_default )
  end
  
  def home_blocks_legacy
    blocks = ActiveSupport::OrderedHash.new
    home_blocks.each do |key, value|
      blocks[ key ] = case( key ) 
      when :top_stories, :my_authors : Array( value )
      when :sections, :topics : home_blocks[ key ].keys.collect{ |k| home_blocks[ key ][ k ] }.select{ |x| !x.nil? }
      else value
      end
    end
    blocks
  end
  
  def show_images?
    preference.image == 1
  end
  
  def power_plan?
    preference.plan_id == 1
  end
  
  def renew?
    preference.renew
  end
  
  def out_of_limit?( name )
    preference.out_of_limit
    #klass = JAPI.const_get( name.to_s.singularize.capitalize + 'Preference')
    #!self.power_plan? && klass.find(:all, :params => { :user_id => self.id }).size > 0
  end
  
  def nav_blocks_order
    @nav_blocks_order ||= home_blocks_order
  end
  
  def random_wizard
    if @wizards.blank?
      @wizards = []
      preference.wizards.each{ |key,value| @wizards.push(key) if value == '1' }
    end
    @wizards.rand
  end
  
  def wizard?( wizard_id )
    preference.wizards[ wizard_id.to_s ] == '1'
  end
  
  def turn_off_wizard( wizard_id )
    preference.wizards.merge!( wizard_id.to_s => 0 )
    j = JAPI::Preference.new( :id => self.id, :wizards => { wizard_id => 0 } )
    j.save
  end
  
  # def set_home_blocks( edition, navigation_links = true )
  #   set_multi_curb if multi_curb.nil?
  #   user_id = new_record? ? 'default' : self.id
  #   @home_blocks = ActiveSupport::OrderedHash.new
  #   edition ||= JAPI::PreferenceOption.parse_edition( self.edition || 'int-en' )
  #   home_blocks_order.each do |pref|
  #     case( pref ) when :top_stories_cluster_group
  #       @home_blocks[:top_stories] = []
  #     when :cluster_groups
  #       @home_blocks[:sections] = []
  #       JAPI::ClusterGroup.async_find( :all, :multi_curb => multi_curb, :params => { :user_id => user_id, :cluster_group_id => 'all', :region_id => edition.region_id, :language_id => edition.language_id } ) do |objects|
  #         @home_blocks[:sections] = objects
  #       end
  #     when :my_authors
  #       @home_blocks[:my_authors] = []
  #       JAPI::Story.async_find( :all, :from => :authors, :multi_curb => multi_curb, :params => { :author_ids => :all, :user_id => self.id, :preview => 1, :language_id => edition.language_id } ) do |objects|
  #         @home_blocks[:my_authors] = [ objects ]
  #       end unless self.id.blank?
  #     when :my_topics
  #       @home_blocks[:topics] = []
  #       JAPI::Topic.async_find( :all, :multi_curb => multi_curb, :params => { :topic_id => :all, :user_id => self.id } ) do | objects |
  #         @home_blocks[:topics] = objects
  #       end unless self.id.blank?
  #     end
  #   end
  #   set_navigation_links( edition, false ) if navigation_links
  #   multi_curb.perform # blocking call
  #   if @home_blocks[:sections].nil?
  #     @home_blocks[:top_stories] = Array( JAPI::ClusterGroup.find( :one, :params => { :user_id => user_id, :cluster_group_id => 'top', :preview => 1, :region_id => edition.region_id, :language_id => edition.language_id } ) )
  #   else
  #     @home_blocks[:top_stories] = Array( @home_blocks[:sections].shift )
  #   end if @home_blocks.key?( :top_stories )
  #   @home_blocks.delete(:top_stories) if @home_blocks.key?( :top_stories ) && @home_blocks[:top_stories].first && @home_blocks[:top_stories].first.clusters.blank?
  #   @home_blocks
  # end
  # 
  # def set_navigation_links( edition, auto_perform = true )
  #   set_multi_curb if multi_curb.nil?
  #   user_id = new_record? ? 'default' : self.id
  #   @navigation_links = ActiveSupport::OrderedHash.new
  #   nav_blocks_order.each do |pref|
  #     case( pref ) when :top_stories_cluster_group
  #       @navigation_links[ :top_stories ] = JAPI::NavigationLink.new( :id => 'top', :name => 'Top Stories', :type => 'cluster_group' )
  #     when :cluster_groups
  #       @navigation_links[ :sections ] = nil 
  #       JAPI::HomeClusterPreference.async_find( :all, :multi_curb => multi_curb, :params => { :user_id => user_id, :language_id => edition.language_id, :region_id => edition.region_id } ) do |results|
  #         @navigation_links[ :sections ] = results.collect{ |pref| 
  #           JAPI::NavigationLink.new( :id => pref.cluster_group.id , :name => pref.cluster_group.name , :type => 'cluster_group' )
  #         }
  #       end
  #       @navigation_links[ :add_section ] = JAPI::NavigationLink.new( :name => 'Add Section', :type => 'new_cluster_group', :remote => true )
  #     when :my_topics
  #       @navigation_links[ :topics ] = nil
  #       JAPI::TopicPreference.async_find( :all, :multi_curb => multi_curb, :params => { :user_id => user_id } ) do |results|
  #         counts_map = JAPI::Topic.home_count_map( results, { :user_id => user_id }, self.preference.default_time_span ) # All topics count are done in parallel.
  #         @navigation_links[ :topics ] = results.collect do |pref|
  #           JAPI::NavigationLink.new( :id => pref.id, :name => pref.name, :translate => false, :type => 'topic' ).tap{ |l| 
  #             l.base =  counts_map[ pref.id ]
  #           }
  #         end
  #       end
  #       @navigation_links[ :add_topic ] = JAPI::NavigationLink.new( :name => 'Add Topic', :type => 'new_topic', :remote => true )
  #       @navigation_links[ :my_topics ] = JAPI::NavigationLink.new( :name => 'My Topics', :type => 'my_topics', :remote => true )
  #     when :my_authors
  #       @navigation_links[ :my_authors ] = JAPI::NavigationLink.new( :name => 'My Authors', :type => 'my_authors' ).tap{ |l| l.base = 0 }
  #       JAPI::Story.async_find( :all, :from => :authors, :multi_curb => multi_curb, :params => { :author_ids => :all, :user_id => self.id, 
  #         :per_page => 0, :time_span => 24.hours.to_i } 
  #       ) do | results |
  #         @navigation_links[ :my_authors ].base = results.facets.count
  #       end
  #     end
  #   end
  #   multi_curb.perform if auto_perform
  #   @navigation_links
  # end
  # 
  # def home_blocks( edition = nil )
  #   return @home_blocks if @home_blocks
  #   set_home_blocks( edition )
  # end
  # 
  # def navigation_links( edition = nil )
  #   return @navigation_links if @navigation_links
  #   set_navigation_links( edition )
  # end
  

end

class CASClient::Frameworks::Rails::Filter  
  # def self.account_login_url(controller)
  #   service_url = read_service_url(controller)
  #   uri = URI.parse(JAPI::Config[:connect][:account_server].to_s + '/login')
  #   uri.query = "service=#{CGI.escape(service_url)}&jwa=1"
  #   log.debug("Generated account login url: #{uri.to_s}")
  #   return uri.to_s
  # end
  # 
  # def self.redirect_to_cas_for_authentication(controller)
  #   redirect_url = ''
  #   if use_gatewaying?
  #     controller.session[:cas_sent_to_gateway] = true
  #     redirect_url << login_url(controller) << "&gateway=true"
  #   else
  #     controller.session[:cas_sent_to_gateway] = false
  #     redirect_url << account_login_url(controller)
  #   end
  #   if controller.session[:previous_redirect_to_cas] &&
  #       controller.session[:previous_redirect_to_cas] > (Time.now - 1.second)
  #     log.warn("Previous redirect to the CAS server was less than a second ago. The client at #{controller.request.remote_ip.inspect} may be stuck in a redirection loop!")
  #     controller.session[:cas_validation_retry_count] ||= 0
  #     if controller.session[:cas_validation_retry_count] > 3
  #       log.error("Redirection loop intercepted. Client at #{controller.request.remote_ip.inspect} will be redirected back to login page and forced to renew authentication.")
  #       redirect_url += "&renew=1&redirection_loop_intercepted=1"
  #     end
  #     controller.session[:cas_validation_retry_count] += 1
  #   else
  #     controller.session[:cas_validation_retry_count] = 0
  #   end
  #   controller.session[:previous_redirect_to_cas] = Time.now
  #   log.debug("Redirecting to #{redirect_url.inspect}")
  #   controller.send(:redirect_to, redirect_url)
  # end
end

JAPI::Connect::InstanceMethods.class_eval do
  
  def logout
    begin
      TICKET_STORE.delete( session[:session_id] ) if TICKET_STORE
    ensure
      CASClient::Frameworks::Rails::GatewayFilter.logout( self, JAPI::Config[:connect][:service] )
    end
  end
  
  def after_japi_connect
    @page_data = PageData.new( current_user, :edition => news_edition, :navigation => true, :auto_perform => false )
    page_data_finalize if page_data_auto_finalize?
  end
  
  def page_data_auto_finalize?
    true
  end
  
  def page_data_finalize
    @page_data.finalize
    current_user.navigation_links = @page_data.navigation_links
  end
  
  # Checks for session validation after 10.minutes
  def session_check_for_validation
    last_st = session.try( :[], :cas_last_valid_ticket )
    # unless last_st
    #   if session[ :cas_user_attrs ]
    #     session[ :cas_user_attrs ] = nil
    #     session[ CASClient::Frameworks::Rails::Filter.client.username_session_key ] = nil
    #   else
    #     session[:cas_sent_to_gateway] = true if request.referer && URI.parse( request.referer ).host != JAPI::Config[:connect][:account_server].host
    #   end
    #   return
    # end
    if last_st.nil? && session[ :cas_user_attrs ].nil?
      session[ :cas_sent_to_gateway ] = true if web_spider? || ( request.referer && URI.parse( request.referer ).host != JAPI::Config[:connect][:account_server].host )
      return
    end
    if request.get? && !request.xhr? && ( session[:revalidate].nil? || session[:revalidate] < Time.now.utc )
      session[:cas_last_valid_ticket] = nil
      session[:revalidate] = JAPI::User.session_revalidation_timeout.from_now
    end
  end
  
  def web_spider?
    request.user_agent =~ /(Googlebot)|(Slurp)|(spider)|(Sogou)|((r|R)obot)|(Mediapartners\-Google)|(msnbot)|(Google\-Site\-Verification)|(ApacheBench)|(facebook)/
  end
  
  def store_referer_location
    request_uri = URI.parse(request.url)
    request_uri.query = nil
    unless session[:request_url] && session[:request_url] == request_uri.to_s
      session[:request_url] = request_uri.to_s
      session[:return_to] = ( params[:referer] || request.referer )
    end
    #log_session_info
  end
  
  def return_to_uri
    URI.parse( session[:return_to] || "" )
  end
  
  def redirect_back_or_default(default, options = {})
    condition = ( options[:if] ? options[:if].call : true ) rescue true
    return_to = session[:return_to]
    session[:return_to] = nil
    session[:request_url] = nil
    redirect_to( condition && !return_to.blank? ? return_to : default )
  end
  
  def uri_path_match?( suri, turi )
    suri = suri.is_a?( URI ) ? suri.dup : URI.parse( suri.to_s )
    suri.query = ''
    turi = turi.is_a?( URI ) ? turi.dup : URI.parse( turi.to_s )
    turi.query = ''
    suri == turi
  end
  
  def set_locale
    params[:locale] = nil if params[:locale].blank? || !JAPI::PreferenceOption.valid_locale?( params[:locale] )
    session[:locale] = params[:locale]
    session[:locale] ||= current_user.locale
    session[:locale] ||= JAPI::PreferenceOption.parse_edition( session[:edition] ).try( :locale ) || 'en'
    I18n.locale = session[:locale]
    params[:locale] = session[:locale] unless params[:locale].blank?
  end
  
  def set_edition
    params[:edition] = session[:edition] if params[:edition].blank? || !JAPI::PreferenceOption.valid_edition?( params[:edition] )
    session[:edition] = params[:edition]
    session[:edition] ||= current_user.edition || JAPI::PreferenceOption.default_country_edition( request.headers['X-GeoIP-Country'] || "" )
    params[:edition] = session[:edition] unless params[:edition].blank?
  end
  
  def restore_mem_cache_cas_last_valid_ticket
    return unless TICKET_STORE
    @last_cas_ticket = TICKET_STORE.get( session[:session_id] )
    session[:cas_last_valid_ticket] = @last_cas_ticket
  end
  
  def store_to_mem_cache_cas_last_valid_ticket
    return unless TICKET_STORE
    if @last_cas_ticket != session[:cas_last_valid_ticket] && session[:cas_last_valid_ticket]
      if @last_cas_ticket
        TICKET_STORE.replace( session[:session_id], session[:cas_last_valid_ticket], 48.hours.to_i )
      else
        TICKET_STORE.add( session[:session_id], session[:cas_last_valid_ticket], 48.hours.to_i )
      end
    end
    session.delete( :cas_last_valid_ticket )
  end
  
  protected :store_referer_location, :session_check_for_validation, :return_to_uri, :set_edition, :restore_mem_cache_cas_last_valid_ticket, :store_to_mem_cache_cas_last_valid_ticket
  
end

JAPI::Connect::UserAccountsHelper.class_eval do
  
  # def url_for_account_server( params = {} )
  #   if @account_server_prefix_options.nil?
  #     account_server_uri ||= JAPI::Config[:connect][:account_server]
  #     @account_server_prefix_options ||= { :host => account_server_uri.host, :port => account_server_uri.port, :protocol => account_server_uri.scheme }
  #   end
  #   @account_server_prefix_options.reverse_merge( params.reverse_merge( :locale => locale, :service => self.request.url ) )
  # end
  
  def login_path( params = {} )
    url_for_account_server( :controller => 'login', :jwa => 1 ).reverse_merge( params )
  end
  
  def logout_path( params = {} )
    url_for_account_server( :controller => 'logout' ).reverse_merge( params )
  end
  
  def upgrade_required_path( params = {} )
    id = params.delete(:id)
    url_for( account_path( params.merge( :action => :upgrade_required, :jar => 1 ) ) ) + "&id=#{id}"
  end
  
  def fb_login_path( params = {} )
    url_for( url_for_account_server( :controller => 'fb', :action => 'login' ).reverse_merge( params ) )
  end
  
  def url_for_account_server( params = {} )
    if @account_server_prefix_options.nil?
      account_server_uri ||= JAPI::Config[:connect][:account_server]
      @account_server_prefix_options ||= { :host => account_server_uri.host, :port => account_server_uri.port, :protocol => account_server_uri.scheme }
    end
    if params.is_a?( Hash )
      @account_server_prefix_options.reverse_merge( params.reverse_merge( :service => CGI.escape( self.request.url ) ) )
    else
      url_for( @account_server_prefix_options.reverse_merge( :controller => '/' ) ) + params
    end
  end
  
end

JAPI::Connect::ClassMethods.class_eval do
  
  def japi_connect_login_required( options = {}, &block )
    filter_options = {}
    filter_options[:except] = Array( options.delete(:skip) ) if options[:skip]
    before_filter :restore_mem_cache_cas_last_valid_ticket, filter_options
    before_filter :session_check_for_validation, filter_options
    if options[:only]
      before_filter :authenticate_using_cas_with_gateway,    :except => options[:only]
      before_filter :authenticate_using_cas_without_gateway, :only => options[:only]
      skip_before_filter :authenticate_using_cas_with_gateway, :only => filter_options[:except] unless filter_options[:except].blank?
    elsif options[:except]
      before_filter :authenticate_using_cas_with_gateway, :only => options[:except]
      before_filter :authenticate_using_cas_without_gateway, :except => options[:except]
      skip_before_filter :authenticate_using_cas_without_gateway, :only => filter_options[:except] unless filter_options[:except].blank?
    else
      before_filter :authenticate_using_cas_without_gateway, filter_options
    end
    before_filter :store_to_mem_cache_cas_last_valid_ticket, filter_options
    before_filter :set_current_user, filter_options
    before_filter :set_edition, filter_options
    before_filter :set_locale, filter_options
    before_filter :check_for_new_users, options.merge( filter_options )
    before_filter :redirect_to_activation_page_if_not_active, options.merge( filter_options )
    block.call if block
    before_filter :after_japi_connect, filter_options
  end
  
  def japi_connect_login_optional( options = {}, &block )
    filter_options = {}
    filter_options[:except] = Array( options.delete(:skip) ) if options[:skip]
    before_filter :restore_mem_cache_cas_last_valid_ticket, filter_options
    before_filter :session_check_for_validation, filter_options
    if options[:only]
      before_filter :authenticate_using_cas_without_gateway,    :except => options[:only]
      before_filter :authenticate_using_cas_with_gateway, :only => options[:only]
      skip_before_filter :authenticate_using_cas_without_gateway, :only => filter_options[:except] unless filter_options[:except].blank?
    elsif options[:except]
      before_filter :authenticate_using_cas_without_gateway, :only => options[:except]
      before_filter :authenticate_using_cas_with_gateway, :except => options[:except]
      skip_before_filter :authenticate_using_cas_with_gateway, :only => filter_options[:except] unless filter_options[:except].blank?
    else
      before_filter :authenticate_using_cas_with_gateway, filter_options
    end
    before_filter :store_to_mem_cache_cas_last_valid_ticket, filter_options
    before_filter :set_current_user, filter_options
    before_filter :set_edition, filter_options
    before_filter :set_locale, filter_options
    before_filter :check_for_new_users, options.merge( filter_options )
    before_filter :redirect_to_activation_page_if_not_active, options.merge( filter_options )
    block.call if block
    before_filter :after_japi_connect, filter_options
  end
  
end

ApplicationController.class_eval do
  extend JAPI::Connect::ClassMethods
  include JAPI::Connect::InstanceMethods
  include JAPI::Connect::UserAccountsHelper
  JAPI::Connect::UserAccountsHelper.instance_methods.each{ |method| self.helper_method( method ) }
end