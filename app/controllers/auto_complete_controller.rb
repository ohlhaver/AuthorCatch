class AutoCompleteController < ApplicationController
  
  def author_name
    @items = JAPI::Author.find(:all, :params => { :q => params[:author][:name], :per_page => 20, :ac => 1 })
    render :inline => "<%= auto_complete_result @items, 'name' %>"
  end
  
  def source_name
    @items = JAPI::Source.find(:all, :params => { :q => params[:source][:name], :per_page => 20, :ac => 1 })
    render :inline => "<%= auto_complete_result @items, 'name' %>"
  end
  
end
