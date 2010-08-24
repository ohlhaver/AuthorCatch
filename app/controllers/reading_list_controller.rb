class ReadingListController < ApplicationController
  
  japi_connect_login_required :except => :whats
  
  skip_before_filter :verify_authenticity_token, :only => [ :create ]
  
  def whats
    @page_title = "Jurnalo - #{t('reading_list.what.label')}"
  end
  
  def index
    @page_data.add do |multi_curb|
      JAPI::StoryPreference.async_find( :all, :multi_curb => multi_curb, :params => { :user_id => current_user.id, :page => params[:page] || 1 } ) do |prefs|
        @prefs = prefs
        JAPI::Story.async_find( :all, :multi_curb => multi_curb, :from => :list, :params => { :story_id => @prefs.collect( &:story_id ) } ) do |stories|
          @stories = stories
        end
      end
    end
    page_data_finalize
    @stories.pagination = @prefs.pagination
    prefs_hash = @prefs.inject({}){ |s,x| s[x.story_id] = x.id; s }
    @stories.collect{ |x| x.reading_list_id = prefs_hash[x.id] }
    @page_title = "Jurnalo - #{I18n.t('navigation.top.reading_list')}"
  end
  
  def create
    pref = JAPI::StoryPreference.new( :story_id => params[:id] )
    pref.prefix_options = { :user_id => current_user.id }
    if pref.save
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Fail'
    end
    redirect_to request.referrer || { :action => :index }
  end
  
  def destroy
    pref = JAPI::StoryPreference.find( params[:id], :params => { :user_id => current_user.id } )
    if pref && pref.destroy
      flash[:notice] = 'Success'
    else
      flash[:error] = 'Fail'
    end
    redirect_to :action => :index
  end
  
  protected
  
  def auto_page_data_finalize
    [ :whats ].include?( action_name.to_sym )
  end

end
