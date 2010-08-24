module AutoCompleteHelper
  
  def author_auto_complete_field( object, method, value = nil )
    @author = value || JAPI::Author.new( :name => '' )
    text_field_with_auto_complete( 'author', 'name', 
      link_to_function( 'Clear' ){ |page| page["#{object}_#{method}"].value = ""; page["author_name"].value = "" }, 
      {}, 
      { 
        :url => { :controller => :auto_complete, :action => :author_name }, 
        :select => 'item_name',
        :after_update_element => %Q(function(element, value){ 
          var hidden_field = $( "#{object}_#{method}" );
          if ( hidden_field ) {
            hidden_field.value = value.getElementsByClassName('item_id')[0].innerHTML
          }
          return false; 
        }) 
      }
    ) + hidden_field( object, method )
  end
  
  def source_auto_complete_field( object, method, value = nil)
    @source = value || JAPI::Source.new( :name => '')
    text_field_with_auto_complete( 'source', 'name', 
      link_to_function( 'Clear' ){ |page| page["#{object}_#{method}"].value = ""; page["source_name"].value = "" }, 
      {}, 
      { 
        :url => { :controller => :auto_complete, :action => :source_name }, 
        :select => 'item_name',
        :after_update_element => %Q(function(element, value){ 
          var hidden_field = $( "#{object}_#{method}" );
          if ( hidden_field ) {
            hidden_field.value = value.getElementsByClassName('item_id')[0].innerHTML
          }
          return false;
        }) 
      }
    ) + hidden_field( object, method )
  end
  
  def text_field_with_auto_complete(object, method, clear_tag = "", tag_options = {}, completion_options = {})
    content_for :custom_javascript do
      auto_complete_field("#{object}_#{method}", { :url => { :action => "auto_complete_for_#{object}_#{method}" } }.update(completion_options))
    end
    (completion_options[:skip_style] ? "" : auto_complete_stylesheet) +
    text_field(object, method, tag_options) + "&nbsp;" + clear_tag +
    content_tag("div", "", :id => "#{object}_#{method}_auto_complete", :class => "auto_complete")
  end
  
  def auto_complete_result(entries, field, phrase = nil)
    return unless entries
    items = entries.map { |entry| content_tag("li", 
      content_tag("span", phrase ? highlight(entry.send(field), phrase) : h(entry.send(field)), :class => 'item_name') +
      content_tag("span", entry.send(:id), :style => 'display:none', :class => 'item_id' ) ) }
    content_tag("ul", items.uniq)
  end
  
end