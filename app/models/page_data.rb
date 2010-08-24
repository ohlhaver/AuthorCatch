# Benchmark.measure{ p = PageData.new(u, :navigation => true, :home => true ) }.to_s

class PageData
  
  attr_reader :multi_curb
  attr_reader :navigation_links
  attr_reader :edition
  attr_reader :home_blocks
  attr_reader :user
  attr_reader :top_stories
  attr_reader :options
  
  def initialize( user, options = {}, &block )
    @multi_curb = Curl::Multi.new
    @multi_curb.pipeline = false
    @multi_curb.max_connects = 48
    @user = user
    options[:auto_perform] = true if options[:auto_perform].nil?
    @options = options
    @edition = ( options[:edition] || JAPI::PreferenceOption.parse_edition( user.edition || 'int-en' ) )
    set_user_preferences
    block.call if block
    self.finalize if options[:auto_perform]
  end
  
  def user_id
    user.new_record? ? 'default' : user.id
  end
  
  def add( &block )
    block.call( multi_curb )
  end
  
  # Needed with passenger 
  # because it used to get hanged indefinitely.
  # Not sure why?. (#Older and buggy curl library.)
  def finalize
    # if defined?( SystemTimer )
    #       count = 0
    #       begin
    #         count += 1
    #         SystemTimer.timeout_after( 30 ) do
    #           multi_curb.perform
    #         end
    #       rescue Timeout::Error 
    #         retry unless count > 2
    #       end
    #     else
    multi_curb.perform
    # end
  end
  
  def set_user_preferences( &block )
    JAPI::HomeDisplayPreference.async_find( :all, :multi_curb => multi_curb, :params => { :user_id => user_id } ){ |prefs|
      user.home_blocks_order = prefs.collect{ |pref| pref.element.code }
      set_home_blocks
      set_navigation_links
    } #if user.home_blocks_order.nil?
    JAPI::Preference.async_find( user_id, :multi_curb => multi_curb ){ |pref|
      user.preference = pref
      set_navigation_links
    } if user.preference.nil?
    JAPI::TopicPreference.async_find( :all, :multi_curb => multi_curb, :params => { :user_id => user_id } ){ |prefs|
      user.topic_preferences = prefs
      set_navigation_links
    } #if user.topic_preferences.nil?
    JAPI::HomeClusterPreference.async_find( :all, :multi_curb => multi_curb, :params => { :user_id => user_id, :region_id => edition.region_id, :language_id => edition.language_id } ){ |prefs|
      user.section_preferences = prefs
      set_navigation_links
    } #if user.section_preferences.nil?
  end
  
  def set_navigation_links
    return unless @navigation_links.nil? && options[:navigation] && user.preference && user.section_preferences && user.topic_preferences && user.home_blocks_order
    @navigation_links = ActiveSupport::OrderedHash.new
    user.nav_blocks_order.each do |pref|
      case( pref ) when :top_stories_cluster_group
        @navigation_links[ :top_stories ] = JAPI::NavigationLink.new( :id => 'top', :name => 'Top Stories', :type => 'cluster_group' )
      when :cluster_groups
        @navigation_links[ :sections ] = user.section_preferences.collect{ |pref| 
          JAPI::NavigationLink.new( :id => pref.cluster_group.id , :name => pref.cluster_group.name , :type => 'cluster_group' )
        }
        @navigation_links[ :add_section ] = JAPI::NavigationLink.new( :name => 'Add Section', :type => 'new_cluster_group', :remote => true )
      when :my_topics
        @navigation_links[ :topics ] = user.topic_preferences.collect{ |pref|
          JAPI::NavigationLink.new( :id => pref.id, :name => pref.name, :translate => false, :type => 'topic' )
        }
        @navigation_links[ :add_topic ] = JAPI::NavigationLink.new( :name => 'Add Topic', :type => 'new_topic', :remote => true )
        @navigation_links[ :my_topics ] = JAPI::NavigationLink.new( :name => 'My Topics', :type => 'my_topics', :remote => true )
        JAPI::Topic.async_home_count_map( multi_curb, user.topic_preferences, { :user_id => user_id }, user.preference.default_time_span ){ |topic|
          @navigation_links[:topics].select{ |l| topic && l.id == topic.id }.each{ |link| link.base = topic }
        } unless user.new_record?
      when :my_authors
        @navigation_links[ :my_authors ] = JAPI::NavigationLink.new( :name => 'My Authors', :type => 'my_authors' ).tap{ |l| l.base = 0 }
        JAPI::Story.async_find( :all, :from => :authors, :multi_curb => multi_curb, :params => { :author_ids => :all, :user_id => user.id, 
          :per_page => 0, :time_span => 24.hours.to_i } 
        ) do | results |
          @navigation_links[ :my_authors ].base = results.facets.try(:count) || 0
        end unless user.new_record?
      end
    end
  end
  
  def set_home_blocks
    return unless options[:home] && @home_blocks.nil? && user.home_blocks_order
    @home_blocks = ActiveSupport::OrderedHash.new
    user.home_blocks_order.each do |pref|
      case( pref ) when :top_stories_cluster_group
        @home_blocks[:top_stories] = []
      when :cluster_groups
        @home_blocks[:sections] = []#ActiveSupport::OrderedHash.new
        JAPI::ClusterGroup.async_find( :all, :multi_curb => multi_curb, :params => { :user_id => user_id, :cluster_group_id => 'all', :region_id => edition.region_id, :language_id => edition.language_id } ) do |objects|
          @home_blocks[:sections] = objects
          if @home_blocks[:sections].nil?
            @home_blocks[:top_stories] = Array( JAPI::ClusterGroup.find( :one, :params => { :user_id => user_id, :cluster_group_id => 'top', :preview => 1, :region_id => edition.region_id, :language_id => edition.language_id } ) )
          else
            @home_blocks[:top_stories] = Array( @home_blocks[:sections].shift )
          end if @home_blocks.key?( :top_stories )
          @home_blocks.delete(:top_stories) if @home_blocks.key?( :top_stories ) && @home_blocks[:top_stories].first && @home_blocks[:top_stories].first.clusters.blank?
        end
        #top_cluster_ids = top_stories.clusters.collect( &:id )
        #user.section_preferences.each do | pref |
        #  JAPI::ClusterGroup.async_find( :all, : )
        #  
        #  @home_blocks[:sections]
        #  # @home_blocks[:sections][pref.cluster_group.id] = nil
        #  # JAPI::ClusterGroup.async_find( :one, :multi_curb => multi_curb, :params => { 
        #  #   :user_id => user_id, :language_id => edition.language_id, :region_id => edition.region_id,
        #  #   :cluster_group_id => pref.cluster_group.id, :preview => 1, :top_cluster_ids => top_cluster_ids } ) do |cluster|
        #  #   @home_blocks[:sections][cluster.id] = cluster
        #  # end
        #end
      when :my_authors
        @home_blocks[:my_authors] = []
        JAPI::Story.async_find( :all, :from => :authors, :multi_curb => multi_curb, :params => { :author_ids => :all, :user_id => user.id, :preview => 1, :language_id => edition.language_id } ) do |objects|
          @home_blocks[:my_authors] = [ objects ]
        end unless user.new_record?
      when :my_topics
        @home_blocks[:topics] = [] # ActiveSupport::OrderedHash.new
        JAPI::Topic.async_find( :all, :multi_curb => multi_curb, :params => { :topic_id => :all, :user_id => user.id } ) do | objects |
          @home_blocks[:topics] = objects
        end unless user.new_record?
        # (user.topic_preferences || []).each do |pref|
        #   @home_blocks[:topics][ pref.id] = nil
        #   JAPI::Topic.async_find( :one, :multi_curb => multi_curb, :params => { :topic_id => pref.id, :user_id => user.id, :preview => 1 } ) do | topic |
        #     @home_blocks[:topics][ topic.id ] = topic
        #   end
        # end unless user.new_record?
      end
    end
  end
  
end