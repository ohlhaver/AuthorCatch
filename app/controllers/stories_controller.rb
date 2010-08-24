class StoriesController < ApplicationController
  
  japi_connect_login_optional :skip => [ :rss ] do
    caches_action :rss, :cache_path => Proc.new{ |c| c.send(:rss_cache_key) }, :expires_in => 5.minutes
    caches_action :show, :cache_path => Proc.new{ |c| c.send(:action_cache_key) }, :expires_in => 24.hours, :if => Proc.new{ |c| c.send(:current_user).new_record? && c.send(:web_spider?) }
  end
  
  def show
    @story = JAPI::Story.find( params[:id] )
    if @story && !web_spider?
      if mobile_device?
        redirect_to @story.url
      else
        set_related_stories
        render :action => :show, :layout => false
      end
    else
      render :text => %Q(<html><head>
        <meta property="og:title" content="#{@story.try(:title) || 'Story Not Found'}"/>
        <meta property="og:site_name" content="Jurnalo.com"/>
        <meta property="og:image" content="#{@story.try(:image)}"/>
      </head><body></body></html>)
    end
  end
  
  def index
    @advanced = false
    @query = params[:q]
    params_options = { :q => params[:q] }
    params_options[:sort_criteria] = sort_criteria
    params_options[:subscription_type] = subscription_type
    @topic_params = JAPI::TopicPreference.extract( params_options )
    params_options.merge!( :page => params[:page], :per_page => params[:per_page], @filter => 4 )
    params_options[:user_id] = current_user.id unless current_user.new_record?
    params_options[:language_id] ||= params[:l] unless params[:l].blank?
    params_options[:language_id] ||= news_edition.language_id if current_user.new_record?
    params_options[:time_span] = params[:ts] unless params[:ts].blank?
    @rss_url = search_rss_url( :edition => session[:edition], :locale => I18n.locale, :oq => obfuscate_encode( params_options.merge( :page => nil ) ), :mode => :simple )
    @page_data.add do |multi_curb|
      JAPI::Story.async_find( :all, :multi_curb => multi_curb, :params => params_options ){ |results| @stories = results }
      JAPI::Author.async_find( :all, :multi_curb => multi_curb, :params => { :q => params[:q], :per_page => 3, :page => 1, :cf => 1 } ){ |results| @authors = results || [] }
      JAPI::Source.async_find( :all, :multi_curb => multi_curb, :params => { :q => params[:q], :per_page => 3, :page => 1 } ){ |results| @sources = results || [] }
    end
    page_data_finalize
    @page_title = I18n.t( "seo.page.title.search", :query => params[:q] )
  end
  
  def advanced
    @topic = JAPI::TopicPreference.new
    @page_title = "Jurnalo - #{I18n.t('search.advance.label')}"
  end
  
  def search_results
    @advanced = true
    filters = ['video', 'opinion', 'blog' ].collect{ |x| [ x, params.delete( x ) ] }
    unless params[:japi_topic_preference].blank? && params[:topic_subscription].blank?
      @topic_params = params.delete( :japi_topic_preference )
      @topic_params = params.delete( :topic_subscription ) if @topic_params.blank?
      params.merge!( @topic_params )
    end
    if params[:topic]
      @auto_complete_params = params.delete( :topic )
      params.merge!( @auto_complete_params )
    end
    JAPI::TopicPreference.normalize!( params ) # Filters should not be merged
    @query =  [ params[:q], params[:qa], params[:qe], params[:qn] ].select{ |x| !x.blank? }.join(' ')
    params_options = JAPI::TopicPreference.extract( params )
    params_options[:sort_criteria] = sort_criteria
    params_options[:subscription_type] = subscription_type
    @topic_params = params_options.dup
    params_options.merge!( :page => params[:page], :per_page => params[:per_page] )
    params_options[@filter] = 4 unless @filter == :all
    params_options[:user_id] = current_user.id unless current_user.new_record?
    params_options[:language_id] ||= params[:l] unless params[:l].blank?
    params_options[:language_id] ||= news_edition.language_id if current_user.new_record?
    params_options[:time_span] = params[:ts] unless params[:ts].blank?
    @rss_url = search_rss_url( :edition => session[:edition], :locale => I18n.locale, :oq => obfuscate_encode( params_options.merge( :page => nil ) ), :mode => :advance )
    @page_data.add do |multi_curb|
      JAPI::Story.async_find( :all, :multi_curb => multi_curb, :from => :advance, :params => params_options ){ |results| @stories = results }
    end
    page_data_finalize
    @authors = []
    @sources = []
    @skip_filters = params[:bp].to_s == '4' || params[:vp].to_s == '4' || params[:op].to_s == '4'
    @skip_blog_filter  = params[:bp].to_s == '0'
    @skip_video_filter = params[:vp].to_s == '0'
    @skip_opinion_filter = params[:op].to_s == '0'
    filters.each{ |y| params[ y.first ] = y.last }
    @page_title = I18n.t( "seo.page.title.search", :query => @query )
    render :action => :index
  end
  
  def rss
    set_edition
    set_locale
    obfuscated_query = params.delete(:oq)
    @param_options = obfuscated_query ? obfuscate_decode( obfuscated_query ) : []
    @query = [ @param_options[:q], @param_options[:qa], @param_options[:qe], @param_options[:qn] ].select{ |x| !x.blank? }.join(' ')
    mode = params[:mode] == 'advance' ? :advance : nil
    @stories = JAPI::Story.find( :all, :from => mode, :params => @param_options )
    pp @stories
    @page_title = I18n.t( "seo.page.title.search", :query => @query )
  end
  
  protected
  
  def set_skyscraper
    @skyscraper = true
  end
  
  def page_data_auto_finalize?
    case(action_name) when 'advanced' : true
    else false end
  end
  
  def set_related_stories
    @skip_story_ids = ( params[:sk] || '' ).split(',').push( @story.id ).uniq
    @referer = params[:rf].blank? ? ( request.referer || root_path ): CGI.unescape( params[:rf] )
    @related_story_params = { :sk => @skip_story_ids.join(','), :rf => CGI.escape( @referer ) }
    referer = base_url( request.referer || '/' ).gsub(/http\:\/\/[^\/]+/, '')
    if (match = referer.match(/\/topics\/(\d+)/))
      params[:topic] = match[1]
    elsif ( match = referer.match(/\/clusters\/(\d+)/) )
      params[:cluster] = match[1]
    elsif params[:topic].blank? && params[:cluster].blank?
      params[:cluster] = @story.cluster.try(:id)
      if params[:cluster].blank? && !params[:japi_topic_preference].blank?
        @related_story_params[:japi_topic_preference] = params.delete( :japi_topic_preference )
        params.merge!( @related_story_params[:japi_topic_preference] )
        JAPI::TopicPreference.normalize!( params )
        params[:search] = JAPI::TopicPreference.extract( params )
      end
    end
    if params[:cluster]
      @cluster = JAPI::Cluster.find( :one, :params => { :cluster_id => params[:cluster], :per_page => 1, :page => 1, :user_id => current_user.id } )
      if @cluster
        @related_stories = JAPI::Story.find( :all, :params => { :q => @cluster.top_keywords.join(' '), :language_id => @cluster.language_id, :time_span => 24.hours, :per_page => 3, :skip_story_ids => @skip_story_ids } )
        @facets = @related_stories.facets
        @related_story_params[:cluster] = params[:cluster]
        @more_results_url = stories_path( :q => @cluster.top_keywords.join(' '), :l => @cluster.language_id, :ts => 24.hours )
      end
    elsif params[:topic]
      @topic = JAPI::Topic.find( :one, :params => { :topic_id => params[:topic] , :time_span => 24.hours, :per_page => 3, :page => 1, :user_id => current_user.id, :skip_story_ids => @skip_story_ids } )
      if @topic && @topic.stories.any?
        @facets = @topic.facets
        @related_stories = @topic.stories
        @related_story_params[:topic] = params[:topic]
         @more_results_url = topic_path( @topic )+ "?ts=#{24.hours}"
      end
    elsif params[:search]
      @related_stories = JAPI::Story.find( :all, :from => :advance, :params => params[:search].merge!( :time_span => 24.hours, :per_page => 3, :user_id => current_user.id, :language_id => @story.language_id,
        :skip_story_ids => @skip_story_ids ) )
      if @related_stories.any?
        @facets = @related_stories.facets
        @more_results_url = search_results_stories_path( :japi_topic_preference => @related_story_params[:japi_topic_preference], :l => @story.language_id, :ts => 24.hours )
      end
    end
    unless @related_stories.blank?
      @related_stories.pop if mobile_device? # Showing two related stories
    end
    # Getting Personalized Stuff for the current story
    author = @story.authors.first
    @author = JAPI::Author.find( author.id ) if author
    @source = JAPI::Source.find( @story.source.id ) if @story.source
    unless current_user.new_record?
      @source_preference = JAPI::SourcePreference.find( nil, :params => { :source_id => @source.id, :user_id => current_user.id } ) if @source
      @author_preference = JAPI::AuthorPreference.find( nil, :params => { :author_id => @author.id,  :user_id => current_user.id } ) if @author
    end
    @author_preference ||= JAPI::AuthorPreference.new( :author_id => @author.id, :preference => nil, :subscribed => false ) if @author
    @source_preference ||= JAPI::SourcePreference.new( :source_id => @source.id, :preference => nil ) if @source
    # multi_curb = Curl::Multi.new
    # @story.authors.each do |author|
    #   JAPI::AuthorPreference.find( nil, :multi_curb => multi_curb, :params => { :author_id => author.id,  :user_id => current_user.id } ) do |result|
    #     @author_preference[ result.author_id ] = result if result
    #   end
    # end
    # JAPI::SourcePreference.find( nil, :muli_curb => multi_curb, :params => { :source_id => @story.source.id, :user_id => current_user.id } ) do |result|
    #   @source_preference = result if result
    # end if @story.source
    # multi_curb.perform
  end
  
  def base_url( url = nil )
    url ||= controller.request.url
    url.gsub(/\?.*/, '')
  end
  
  def action_cache_key
    [ controller_name, action_name, params[:id].to_i ].join('-')
  end
  
  def rss_cache_key
    [ 'search', params[:oq], params[:edition], params[:locale] ].join('-')
  end
  
end