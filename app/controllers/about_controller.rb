class AboutController < ApplicationController
  
  japi_connect_login_optional
  before_filter :set_page_title
  
  def imprint
  end
  
  def about
  end
  
  def privacy
  end
  
  def help
  end
  
  def power
  end
  
  protected
  
  def set_page_title
    @page_title = "Jurnalo - #{I18n.t( "jurnalo.#{action_name}.label" )}"
  end
end
