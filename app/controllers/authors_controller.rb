class AuthorsController < ApplicationController
  
  before_filter :store_referer_location, :only => [ :rate, :subscribe, :unsubscribe, :hide, :up, :down ]
  
  japi_connect_login_required :except => [ :show, :top, :whats, :page, :my ] do
    caches_action :show, :cache_path => Proc.new{ |c| c.send(:action_cache_key) }, :expires_in => 5.minutes, :if => Proc.new{ |c| c.send( :current_user ).new_record? }
  end
  
  before_filter :correct_param_id
  before_filter :set_author_filter_var
  skip_before_filter :verify_authenticity_token, :only => [ :subscribe ]
  
  def whats
    page_data_finalize
    @page_title = "Jurnalo - #{t('authors.what.label')}"
  end
  
  def page
    @author = JAPI::Author.find( params[:id] )
    if @author && !web_spider?
      redirect_to author_path( @author )
    else
      render :text => %Q(<html><head>
        <meta property="og:title" content="#{@author.try(:name) || I18n.t('author.not.found')}"/>
        <meta property="og:site_name" content="Jurnalo.com"/>
      </head><body></body></html>)
    end
  end
  
  def show
    # jap = 1 is additional parameter to put the author into priority list on page view
    additional_attrs = current_user.new_record? ? {} : { :jap => 1 }
    @page_data.add do |multi_curb|
      JAPI::Author.async_find( params[:id], :multi_curb => multi_curb, :params => additional_attrs ){ |result| @author = result || JAPI::Author.new( :name => I18n.t( 'author.not.found' ) ) }
      @author_preference ||= JAPI::AuthorPreference.new( :author_id => params[:id], :preference => nil, :subscribed => false )
      JAPI::AuthorPreference.async_find( nil, :multi_curb => multi_curb, :params => { :author_id => params[:id],  :user_id => current_user.id } ) do |result|
        @author_preference = result if result
      end unless current_user.new_record?
      JAPI::Story.async_find( :all, :multi_curb => multi_curb, :params => { :author_ids => params[:id], :page => params[:page] || '1', :all => 1 }, :from => :authors ){ |results| @stories = results }
    end
    page_data_finalize
    @page_title = I18n.t( "seo.page.title.author", :name => @author.name )
  end
  
  def top
    @page_data.add do |multi_curb|
      req_params =  { :author_ids => 'top', :user_id => current_user.id, :page => params[:page] || '1' }
      req_params.merge!( :language_id => JAPI::PreferenceOption.language_id( I18n.locale ) ) unless I18n.locale.to_s == 'de'
      req_params[:per_page] = params[:per_page] if params[:per_page]
      JAPI::Story.async_find( :all, :multi_curb => multi_curb, :params => req_params, :from => :authors) do |result|
        @stories= result
      end
    end
    page_data_finalize
  end
  
  # display list of subscribed author stories
  def my
    #if current_user.new_record?
    #  redirect_to :action => :whats
    #  return false
    #end
    return list if params[:list] == '1'
    @page_data.add do |multi_curb|
      req_params =  { :author_ids => 'all', :user_id => current_user.id, :page => params[:page] || '1' }
      req_params[:per_page] = params[:per_page] if params[:per_page]
      JAPI::Story.async_find( :all, :multi_curb => multi_curb, :params => req_params, :from => :authors) do |result|
        @stories= result
      end
    end

    page_data_finalize
    render :action => :my_author_stories
  end
  
  # display list of authors
  def list
    params_options = { :page => params[:page] || 1, :per_page => params[:per_page], :user_id => current_user.id }
    params_options[:scope] = :fav if @author_filter == :subscribed
    params_options[:scope] = :pref if @author_filter == :rated
    @page_data.add do |multi_curb|
      JAPI::AuthorPreference.async_find( :all, :multi_curb => multi_curb, :params => params_options ){ |results| @author_prefs = results }
    end
    page_data_finalize
    #if @author_prefs.blank?
    #  redirect_to :action => :whats
    #  return false
    #end
    render :action => :my_authors
  end
  
  def rate
    # current_user.set_preference
    # if current_user.out_of_limit?( :authors )
    #   session[:return_to] = nil
    #   redirect_to upgrade_required_path( :id => 3 )
    #   return
    # end
    pref = ( JAPI::AuthorPreference.find( nil, :params => { :author_id => params[:id],  :user_id => current_user.id } ) || 
        JAPI::AuthorPreference.new( :author_id => params[:id] ) )
    pref.prefix_options = { :user_id => current_user.id, :jap => 1 }
    pref.preference = ( Integer( params[:rating] || "" ) rescue nil )
    unless pref.save
      flash[:error] = 'Error'
    end
    redirect_back_or_default( :action => :my, :list => 1, :rated => 1 )
  end
  
  def subscribe
    # current_user.set_preference
    # if current_user.out_of_limit?( :authors )
    #   session[:return_to] = nil
    #   redirect_to upgrade_required_path( :id => 3 )
    #   return
    # end
    pref = ( JAPI::AuthorPreference.find( nil, :params => { :author_id => params[:id],  :user_id => current_user.id } ) ||
      JAPI::AuthorPreference.new( :author_id => params[:id] ) )
    pref.prefix_options = { :user_id => current_user.id, :jap => 1 }
    pref.subscribed = true
    if pref.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Error'
    end
    redirect_back_or_default( :action => :my, :list => 1, :subscribed => 1 )
  end
  
  def unsubscribe
    pref = JAPI::AuthorPreference.find( nil, :params => { :author_id => params[:id],  :user_id => current_user.id } )
    pref.subscribed = false if pref
    if pref && pref.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Error'
    end
    redirect_back_or_default( :action => :my, :list => 1, :subscribed => 1 )
  end
  
  # My Authors Hide
  def hide
    my_authors_id = JAPI::PreferenceOption.homepage_display_id(:my_authors)
    @my_authors = JAPI::HomeDisplayPreference.new( :id => my_authors_id ).tap do |t|
      t.prefix_options = {
        :user_id => current_user.id,
        :homepage_box_id => my_authors_id
      }
    end
    if @my_authors.destroy
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( :action => :index, :controller => :home )
  end
  
  # My Authors Up
  def up
    my_authors_id = JAPI::PreferenceOption.homepage_display_id(:my_authors)
    @my_authors = JAPI::HomeDisplayPreference.new( :id => my_authors_id ).tap do |t|
      t.prefix_options = {
        :user_id => current_user.id,
        :homepage_box_id => my_authors_id,
        :reorder => :up
      }
    end
    if @my_authors.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( :action => :index, :controller => :home )
  end
  
  # My Authors Down
  def down
    my_authors_id = JAPI::PreferenceOption.homepage_display_id(:my_authors)
    @my_authors = JAPI::HomeDisplayPreference.new( :id => my_authors_id ).tap do |t|
      t.prefix_options = {
        :user_id => current_user.id,
        :homepage_box_id => my_authors_id,
        :reorder => :down
      }
    end
    if @my_authors.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Failure'
    end
    redirect_back_or_default( :action => :index, :controller => :home )
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
