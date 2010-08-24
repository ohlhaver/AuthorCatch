# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  protect_from_forgery
  
  filter_parameter_logging :password
  
  include JAPI::Connect
  
  before_filter :set_filter_var, :set_category_id_var, :reset_per_page, :prepare_for_mobile, :set_facebook_login_url, :set_content_column_count, :set_skyscraper
  after_filter :reset_session_params
  
  layout 'with_navigation'
  
  helper_method :sort_criteria, :subscription_type, :time_span, :video_pref, :blog_pref, :opinion_pref, :cluster_sort_criteria, :mobile_device?
  
  include ExceptionNotification::Notifiable
  
  #before_filter :log_session_info
  protected
  
  def reset_session_params
    params[:locale] = nil
    params[:edition] = nil
    params[:ticket] = nil
    params[:authenticity_token] = nil
  end
  
  def reset_per_page
    params[:per_page] = nil
  end
  
  def set_category_id_var
    @category_id = params[:ctid].to_i == 0 ? :all : params[:ctid].to_i
  end
  
  def set_filter_var
    @filter = :all
    @filter = :blog if params[:blog] == '1'
    @filter = :video if params[:video] == '1'
    @filter = :opinion if params[:opinion] == '1'
  end
  
  def time_span
    Integer( params[:ts] || current_user.preference.default_time_span || JAPI::PreferenceOption.time_span_options.last.id ) rescue JAPI::PreferenceOption.time_span_options.last.id
  end
  
  def video_pref
    Integer( params[:vp] || current_user.preference.video || 2 ) rescue 2
  end
  
  def opinion_pref
    Integer( params[:op] || current_user.preference.opinion || 2 ) rescue 2
  end
  
  def blog_pref
    Integer( params[:bp] || current_user.preference.blog || 2 ) rescue 2
  end
  
  def sort_criteria
    Integer( params[:sc] || current_user.preference.default_sort_criteria || '0' ) rescue 0
  end
  
  alias_method :cluster_sort_criteria, :sort_criteria
  
  def sort_criteria=( value )
    params[:sc] = value
  end
  
  def subscription_type
    Integer( params[:st] || current_user.preference.subscription_type || '0' ) rescue 0
  end
  
  def subscription_type=( value )
    params[:st] = value
  end
  
  private
  
  def set_content_column_count
    @content_column_count = 1
  end
  
  def set_skyscraper
    @skyscraper = false
  end
  
  def mobile_device?
    request.user_agent =~ /(Mobile)|(webOS)|(SymbianOS)|(MIDP-\d\.\d)|(PalmSource)|(SAMSUNG-SGH)/
  end
  
  def prepare_for_mobile
    request.format = :mobile if mobile_device?
  end
  
  def set_facebook_login_url
    @facebook_login_url = fb_login_path
  end
  
  def set_current_user_from_id
    params[:id] = nil if params[:id] == 'default'
    @current_user = JAPI::User.new( :id => params[:id] )
  end
  
  def obfuscate_decode( encoded_string )
    cipher = encoded_string.tr('-_','+/').unpack('m')
    data = Marshal.load( cipher.first ) rescue nil
    raise ActionController::UnknownAction, encoded_string unless data
    return data
  end
  
  # The string is url safe
  def obfuscate_encode( object )
    cipher = [ Marshal.dump( object ) ]
    cipher.pack('m').tr('+/','-_').gsub("\n",'')
  end
  
end
