class SourcesController < ApplicationController
  
  before_filter :store_referer_location, :only => [ :rate ]
  
  japi_connect_login_required :except => [ :show, :whats, :page ] do
    caches_action :show, :cache_path => Proc.new{ |c| c.send(:action_cache_key) }, :expires_in => 5.minutes, :if => Proc.new{ |c| c.send( :current_user ).new_record? }
  end
  
  before_filter :correct_param_id
  
  def whats
    @page_title = "Jurnalo - #{t('source.what.label')}"
  end
  
  def page
    @source = JAPI::Source.find( params[:id] )
    if @source && !web_spider?
      redirect_to source_path( @source )
    else
      render :text => %Q(<html><head>
        <meta property="og:title" content="#{@source.try(:name) || I18n.t('source.not.found')}"/>
        <meta property="og:site_name" content="Jurnalo.com"/>
      </head><body></body></html>)
    end
  end
  
  def show
    @page_data.add do |multi_curb|
      JAPI::Source.async_find( params[:id], :multi_curb => multi_curb ){ |source| @source =  source || JAPI::Source.new( :name => I18n.t( 'source.not.found' ) )}
      @source_preference ||= JAPI::SourcePreference.new( :source_id => params[:id], :preference => nil )
      JAPI::SourcePreference.async_find( nil, :multi_curb => multi_curb, :params => { :source_id => params[:id],  :user_id => current_user.id } ) do |result|
        @source_preference = result if result
      end unless current_user.new_record?
      JAPI::Story.async_find( :all, :from => :sources, :multi_curb => multi_curb, 
        :params => { :source_id => params[:id], :category_id => ( @category_id == :all ? nil : @category_id ), :page => params[:page] || '1' }
      ) do |result|
        @stories = result
        @categories = JAPI::PreferenceOption.category_options.select{ |opt| @stories.facets.category_count( opt.id ) > 0 }
      end
    end
    page_data_finalize
    @page_title = "Jurnalo - #{@source.name}"
  end
  
  def rate
    # current_user.set_preference
    # if current_user.out_of_limit?( :sources )
    #   session[:return_to] = nil
    #   redirect_to upgrade_required_path( :id => 2 )
    #   return
    # end
    pref = ( JAPI::SourcePreference.find( nil, :params => { :source_id => params[:id],  :user_id => current_user.id } ) || 
        JAPI::SourcePreference.new( :source_id => params[:id] ) )
    pref.prefix_options = { :user_id => current_user.id }
    pref.preference = ( Integer( params[:rating] || "" ) rescue nil )
    unless pref.save
      flash[:error] = 'Error'
    end
    redirect_back_or_default( :action => :show, :id => params[:id] )
  end
  
  protected
  
  def action_cache_key
    [ controller_name, action_name, session[:edition], session[:locale], params[:id].to_i, @category_id, params[:page] || 1 ].join('-')
  end
  
  def set_skyscraper
    @skyscraper = true
  end
  
  def correct_param_id
    params[:id] = params[:id].match(/(\d+)/).try(:[], 1) unless params[:id].blank?
  end
  
  def auto_page_data_finalize?
    [ :whats ].include?( action_name.to_sym )
  end
  
end
