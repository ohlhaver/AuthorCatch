class SectionsController < ApplicationController
  
  before_filter :store_referer_location, :only => [ :create, :destroy, :hide, :up, :down ]
  
  japi_connect_login_required :except => :show, :skip => [ :rss ] do
    caches_action :rss, :cache_path => Proc.new{ |c| c.send(:rss_cache_key) }, :expires_in => 5.minutes
    caches_action :show, :cache_path => Proc.new{ |c| c.send(:action_cache_key) }, :expires_in => 5.minutes, :if => Proc.new{ |c| c.send( :current_user ).new_record? }
  end
  
  def show
    params_options = { 
      :user_id => current_user.id, :page => params[:page], 
      :language_id => news_edition.language_id, :region_id => news_edition.region_id,
      :cluster_group_id => params[:id], :per_page => params[:per_page] 
    }
    @page_data.add do |multi_curb|
      JAPI::ClusterGroup.async_find( :one, :multi_curb => multi_curb, :params => params_options ) do |section|
        @section = section
      end
    end
    page_data_finalize
    @rss_url = section_rss_url( :locale => I18n.locale, :oq => obfuscate_encode( :cluster_group_id => params[:id], :user_id => current_user.id, 
      :language_id => news_edition.language_id, :region_id => news_edition.region_id ) )
    @page_title = "Jurnalo - #{I18n.t("navigation.main.#{@section.name}")}"
  end
  
  def rss
    set_locale
    params_options = params[:oq] ? obfuscate_decode( params[:oq] ) : nil
    @section = JAPI::ClusterGroup.find( :one, :params => params_options )
    @page_title = "Jurnalo - #{I18n.t("navigation.main.#{@section.name}")}"
    @feed_url = section_url( params_options[ :cluster_group_id ], :locale => params[:locale] )
  end
  
  def create
    @section = JAPI::HomeClusterPreference.new( :value => params[:preference_id] ).tap do |x| 
      x.prefix_options = { :region_id => news_edition.region_id, :language_id => news_edition.language_id, :user_id => current_user.id }
    end
    if @section.save
      flash[:notice] = 'Section Created Successfully.'
      redirect_to request.referer || { :action => :show, :id => @section.id }
    else
      flash[:error] = 'Error while creating section.'
      redirect_back_or_default( :action => :index, :controller => :home )
    end
  end
  
  def destroy
    @section = JAPI::HomeClusterPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = { 
        :user_id => current_user.id, 
        :region_id => news_edition.region_id, 
        :language_id => news_edition.language_id, 
        :cluster_group_id => params[:id]  }
    end
    if @section.destroy
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( { :action => :index, :controller => :home }, :if => Proc.new{ !uri_path_match?( request.url, return_to_uri ) } )
  end
  
  def hide
    top_stories_id = params[:id] == 'top' ? JAPI::PreferenceOption.homepage_display_id(:top_stories_cluster_group) : -1
    @top_section = JAPI::HomeDisplayPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = {
        :user_id => current_user.id,
        :homepage_box_id => top_stories_id
      }
    end
    if @top_section.destroy
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( :action => :index, :controller => :home )
  end
  
  def all_section_up
    cluster_groups_id = JAPI::PreferenceOption.homepage_display_id(:cluster_groups)
    @cluster_groups = JAPI::HomeDisplayPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = {
        :user_id => current_user.id,
        :homepage_box_id => cluster_groups_id,
        :reorder => :up
      }
    end
    if @cluster_groups.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( :action => :index, :controller => :home )
  end
  
  def all_section_down
    cluster_groups_id = JAPI::PreferenceOption.homepage_display_id(:cluster_groups)
    @cluster_groups = JAPI::HomeDisplayPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = {
        :user_id => current_user.id,
        :homepage_box_id => cluster_groups_id,
        :reorder => :down
      }
    end
    if @cluster_groups.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( :action => :index, :controller => :home )
  end
  
  def top_section_up
    top_stories_id = JAPI::PreferenceOption.homepage_display_id(:top_stories_cluster_group)
    @top_section = JAPI::HomeDisplayPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = {
        :user_id => current_user.id,
        :homepage_box_id => top_stories_id,
        :reorder => :up
      }
    end
    if @top_section.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( :action => :show, :id => 'top' )
  end
  
  def top_section_down
    top_stories_id = JAPI::PreferenceOption.homepage_display_id(:top_stories_cluster_group)
    @top_section = JAPI::HomeDisplayPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = {
        :user_id => current_user.id,
        :homepage_box_id => top_stories_id,
        :reorder => :down
      }
    end
    if @top_section.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( :action => :show, :id => 'top' )
  end
  
  def up
    return top_section_up if params[:id] == 'top'
    return all_section_up if params[:id] == 'all'
    @section = JAPI::HomeClusterPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = { 
        :user_id => current_user.id, 
        :reorder => :up,
        :region_id => news_edition.region_id, 
        :language_id => news_edition.language_id, 
        :cluster_group_id => params[:id]
      }
    end
    if @section.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Error'
    end
    redirect_back_or_default( :action => :show, :id => @section.id )
  end
  
  def down
    return top_section_down if params[:id] == 'top'
    return all_section_down if params[:id] == 'all'
    @section = JAPI::HomeClusterPreference.new( :id => params[:id] ).tap do |t|
      t.prefix_options = { 
        :user_id => current_user.id, 
        :reorder => :down,
        :region_id => news_edition.region_id, 
        :language_id => news_edition.language_id, 
        :cluster_group_id => params[:id] 
      }
    end
    if @section.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Error'
    end
    redirect_back_or_default( :action => :show, :id => @section.id )
  end
  
  protected
  
  def action_cache_key
    [ controller_name, action_name, session[:edition], session[:locale], params[:id], params[:page] || 1 ].join('-')
  end
  
  def rss_cache_key
    [ 'section', params[:oq], params[:locale] ].join('-')
  end
  
  def auto_page_data_finalize?
    false
  end
  
end
