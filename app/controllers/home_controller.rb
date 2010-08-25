class HomeController < ApplicationController
  
  before_filter :store_referer_location, :only => [ :rate, :subscribe, :unsubscribe, :hide, :up, :down ]
  
  japi_connect_login_required :except => [ :show, :top, :whats, :page, :my, :index ] do
    #caches_action :show, :cache_path => Proc.new{ |c| c.send(:action_cache_key) }, :expires_in => 5.minutes, :if => Proc.new{ |c| c.send( :current_user ).new_record? }
  end
  
  before_filter :correct_param_id
  before_filter :set_author_filter_var
  skip_before_filter :verify_authenticity_token, :only => [ :subscribe ]
  
  def whats
    page_data_finalize
    @page_title = "Jurnalo - #{t('authors.what.label')}"
  end
  
  def index
    params_options = { 
      :user_id => current_user.id, :page => params[:page], 
      :language_id => news_edition.language_id, :region_id => news_edition.region_id,
      :cluster_group_id => 136, :per_page => params[:per_page] 
    }
    @page_data.add do |multi_curb|
      JAPI::ClusterGroup.async_find( :one, :multi_curb => multi_curb, :params => params_options ) do |section|
        @section = section
      end
    end
    
    params_options = { 
      :user_id => current_user.id, :page => params[:page], 
      :language_id => news_edition.language_id, :region_id => news_edition.region_id,
      :cluster_group_id => 232, :per_page => params[:per_page] 
    }
    @page_data.add do |multi_curb|
      JAPI::ClusterGroup.async_find( :one, :multi_curb => multi_curb, :params => params_options ) do |section|
        @sectionen = section
      end
    end
    
    
    page_data_finalize
    
    
    
    #if current_user.new_record?
    #  redirect_to :action => :whats
    #  return false
    #end
    #return list if params[:list] == '1'
    @page_data.add do |multi_curb|
      req_params =  { :author_ids => 'all', :user_id => current_user.id, :page => params[:page] || '1' }
      req_params[:per_page] = params[:per_page] if params[:per_page]
      JAPI::Story.async_find( :all, :multi_curb => multi_curb, :params => req_params, :from => :authors) do |result|
        @stories= result
        @stories = @stories.find_all{|s| Time.new - s.created_at < 86400 }
        
      end
    end
    page_data_finalize
    #render :action => :my_author_stories
      @stories = @stories + @section.stories + @sectionen.stories
      @stories = @stories.sort_by {|u| - u.id } 
  end
  
  protected
  
  def action_cache_key
    [ controller_name, action_name, session[:edition], session[:locale], params[:id].to_i, params[:page] || 1 ].join('-')
  end
  
  def set_skyscraper
    @skyscraper = true
  end
  
  def page_data_auto_finalize?
    false
  end
  
  def set_author_filter_var
    @author_filter = :all 
    @author_filter = :subscribed if params[:subscribed] == '1'
    @author_filter = :rated if params[:rated] == '1'
  end
  
  def correct_param_id
    params[:id] = params[:id].match(/(\d+)/).try(:[], 1) unless params[:id].blank?
  end
  
end
  

