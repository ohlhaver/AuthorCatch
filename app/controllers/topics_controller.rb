class TopicsController < ApplicationController
  
  before_filter :store_referer_location, :only => [ :destroy, :unhide, :hide, :up, :down ]
  japi_connect_login_required :except => [ :whats, :create, :index ], :skip => [ :rss ] do
    caches_action :rss, :cache_path => Proc.new{ |c| c.send(:rss_cache_key) }, :expires_in => 5.minutes
  end
  
  def whats
    @topic  = JAPI::TopicPreference.new
    @page_title = "Jurnalo - #{t('topic.label.what')}"
  end
  
  def index
    if current_user.new_record?
      redirect_to :action => :whats
      return false
    end
    params_options =  { :topic_id => :my, :user_id => current_user.id }
    @page_data.add do |multi_curb|
      JAPI::Topic.async_find( :all, :multi_curb => multi_curb, :params => params_options ) do |result| 
        @topics = result
      end
    end
    page_data_finalize
    if @topics.blank?
      redirect_to :action => :whats
      return false
    end
  end
  
  def show
    params_options = {}
    @page_data.add do |multi_curb|
      JAPI::TopicPreference.async_find( params[:id], :multi_curb => multi_curb, :params => { :user_id => current_user.id } ) do |result|
        @topic_preference = result
        self.sort_criteria = @topic_preference.sort_criteria if params[:sc].blank?
        self.subscription_type = @topic_preference.subscription_type if params[:st].blank?
        params_options = { :topic_id => params[:id], :page => params[:page],
          :per_page => params[:per_page], :user_id => current_user.id, 
          :sort_criteria => sort_criteria, :subscription_type => subscription_type, @filter => 4 }
        params_options[ :time_span ] = params[:ts] unless params[:ts].blank?
        JAPI::Topic.async_find( :one, :multi_curb => multi_curb, :params => params_options ) do |topic|
          @topic = topic
        end
      end
    end
    page_data_finalize
    @rss_url = topic_rss_url( :locale => I18n.locale, :oq => obfuscate_encode( :topic_id => params[:id], :user_id => current_user.id ) )
    @page_title = @page_title = I18n.t( "seo.page.title.search", :query => @topic.name )
  end
  
  def rss
    set_locale
    params_options = obfuscate_decode( params[:oq] || "" )
    @topic = JAPI::Topic.find( :one, :params => params_options )
    @page_title = @page_title = I18n.t( "seo.page.title.search", :query => @topic.name )
    @feed_url = topic_url( params_options[ :topic_id ], :locale => params[:locale] )
  end

  def new
    current_user.set_preference
    if current_user.out_of_limit?( :topics )
      session[:return_to] = nil
      redirect_to upgrade_required_path( :id => 1 )
      return
    end
    page_data_finalize
    @topic = JAPI::TopicPreference.new( params[:japi_topic_preference] || {} ).parse_auto_complete_params!( params )
    if params[:advance] == '1'
      @topic.sort_criteria ||= sort_criteria
      @topic.blog ||= blog_pref
      @topic.video ||= video_pref
      @topic.opinion ||= opinion_pref
      @topic.time_span ||= time_span
      @topic.subscription_type ||= subscription_type
    end
  end
  
  def create
    unless logged_in?
      redirect_to new_topic_path( :japi_topic_preference => params[:japi_topic_preference], :advance => params[:advance] )
      return
    end
    @topic = JAPI::TopicPreference.new( params[:japi_topic_preference] ).tap do |t| 
      t.prefix_options = { :user_id => current_user.id } 
      t.home_group = true
      t.email_alert = true
      t.parse_auto_complete_params!( params )
    end
    if @topic.save
      flash[:notice] = 'Success'
      redirect_to topic_path( @topic )
    else
      params[:advance] ||= @topic.errors.count > 1 ? '0' : '1'
      flash[:error] = @topic.errors.full_messages.join('\n')
      render :action => :new
    end
  end
  
  def edit
  end
  
  def destroy
    @topic = JAPI::TopicPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = { :user_id => current_user.id }
    end
    if @topic.destroy
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( { :action => :index }, :if => Proc.new{ !uri_path_match?( request.url, return_to_uri ) } )
  end
  
  def unhide
    @topic = JAPI::TopicPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = { :user_id => current_user.id }
      t.home_group = true
    end
    if @topic.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( :action => :show, :id => @topic )
  end
  
  def hide
    @topic = JAPI::TopicPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = { :user_id => current_user.id }
      t.home_group = false
    end
    if @topic.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( :action => :show, :id => @topic )
  end
  
  def up
    return move_up_my_topics if params[:id] == 'my'
    @topic = JAPI::TopicPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = { :user_id => current_user.id, :reorder => :up }
    end
    if @topic.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default(:action => :show, :id => @topic )
  end
  
  def down
    return move_down_my_topics if params[:id] == 'my'
    @topic = JAPI::TopicPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = { :user_id => current_user.id, :reorder => :down }
    end
    if @topic.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( :action => :show, :id => @topic )
  end
  
  def move_up_my_topics
    my_topics_id = JAPI::PreferenceOption.homepage_display_id(:my_topics)
    @topic = JAPI::HomeDisplayPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = {
        :user_id => current_user.id,
        :homepage_box_id => my_topics_id,
        :reorder => :up
      }
    end
    if @topic.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( :action => :index )
  end
  
  def move_down_my_topics
    my_topics_id = JAPI::PreferenceOption.homepage_display_id(:my_topics)
    @topic = JAPI::HomeDisplayPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = {
        :user_id => current_user.id,
        :homepage_box_id => my_topics_id,
        :reorder => :down
      }
    end
    if @topic.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( :action => :index )
  end
  
  protected
  
  def rss_cache_key
    [ 'topic', params[:oq], params[:locale] ].join('-')
  end
  
  def cas_filter_allowed?
    case( action_name ) when 'create' : false 
    else true end
  end
  
  def auto_page_data_finalize?
    [ :what ].include?( action_name.to_sym )
  end
  
  def set_skyscraper
    @skyscraper = true
  end
  
end
