class ClustersController < ApplicationController
  
  japi_connect_login_required :except => :show
  
  def show
    cluster_id = params[:id].match(/^(\d+)/).try(:[], 1)
    @cluster = JAPI::Cluster.find(:one, :params => { 
      :cluster_id => params[:id], :per_page => params[:per_page], 
      :sort_criteria => sort_criteria, :user_id => current_user.id, 
      :page => params[:page], @filter => '1' } ) || JAPI::Cluster.find( :stories => [] )
    raise ActiveRecord::RecordNotFound unless @cluster
    @page_title = I18n.t( "seo.page.title.cluster_group",  :name => @cluster.top_keywords.join(' - ').to_s )
  end
  
  protected
  
  def set_skyscraper
    @skyscraper = true
  end

end
