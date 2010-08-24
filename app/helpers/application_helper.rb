# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  include AutoCompleteHelper
  
  def render_rss_for_cluster( cluster, xml, options = {} )
    story = cluster.stories.first
    block = options[:block]
    block_key = options[:block_key]
    xml.item do
      xml.title story.title
      xml.link cluster_url( cluster, :only_path => false )
      xml.pubDate story.created_at.to_s(:rfc822)
      xml.guid cluster_url( cluster, :only_path => false )
      xml.source( story.source.name, :url => story.url )
      xml.category( block_name( block_key, block ) ) if block && block_key
      xml.description cluster.top_keywords.join(' - ')
      #xml.author( story.authors.first.name ) if story.authors.first
      xml.enclosure( :url => cluster.image, :length => "10240", :type => "image/jpeg", :source => cluster.url ) if cluster.image
      #xml.tag!( "media:content", :url => cluster.image, :medium => "image", :height => "80", :width => "80" ) if cluster.image
      #xml.tag!( "media:copyright", "Image Copyright", :url => cluster.url )  if cluster.image
    end
  end
  
  def render_rss_for_story( story, xml, options = {} )
    block = options[:block]
    block_key = options[:block_key]
    xml.item do
      xml.title story.title
      xml.link story_url( story, :only_path => false )
      xml.pubDate story.created_at.to_s(:rfc822)
      xml.guid story_url( story, :only_path => false )
      xml.source( story.source.name, :url => story.url )
      xml.category( block_name( block_key, block ) ) if block && block_key
      xml.author( story.authors.first.name ) if story.authors.first
      xml.enclosure( :url => story.image, :length => "7063", :type => "image/jpeg" ) if story.image
      #xml.tag!( "media:content", :url => story.image, :medium => "image", :height => "80", :width => "80" ) if story.image
    end
  end
  
  def block_name( key, block )
    case( key.to_s ) when 'top_stories', 'sections' : t("navigation.main.#{block.name}")
    when 'my_authors' : t('navigation.main.my_authors')
    when 'topics' : block.name  end
  end
  
  def one_column_layout?
    @content_column_count == 1
  end
  
  def content_block_position
    return "grid_4 #{cycle( 'alpha', 'omega', :name => 'cluster_preview' )}" if @content_column_count == 2
  end
  
  def reset_content_block_clearfix
    if @content_column_count == 2
      reset_cycle( 'clearfix_preview' )
      reset_cycle( 'cluster_preview' )
      # klass = cycle( "start_clearfix", "1", "2", "end_clearfix", :name => 'clearfix_class') 
      # end_clearfix_div_tag( true ) unless klass == "start_clearfix"
      # reset_cycle( 'clearfix_class')
    end
  end
  
  def content_block_clearfix
    return cycle( '', '<br clear="all"/><div class="clearfix"></div>', :name => 'clearfix_preview' ) if @content_column_count == 2
  end
  
  def story_block_with_image_position
    return 'grid_9 omega' if controller.response.layout =~ /without_navigation/
    return 'grid_6 omega' if @content_column_count == 1
  end
  
  # def start_clearfix_div_tag
  #   return unless @content_column_count == 2
  #   klass = cycle( "start_clearfix", "1", "2", "end_clearfix", :name => 'clearfix_class') 
  #   return "<div class='clearfix'>" if klass == "start_clearfix"
  # end
  # 
  # def end_clearfix_div_tag( force = false )
  #   return unless @content_column_count == 2
  #   klass = cycle( "start_clearfix", "1", "2", "end_clearfix", :name => 'clearfix_class' )
  #   return "</div>" if force || klass == "end_clearfix" 
  # end
  
  
  def js_related_links_fragments
    " var elem = $('search_topic_form');
      if ( elem ){ 
        elem.action = this.href;
        elem.method = 'GET';
        elem.submit();
        return false;
      }
      elem = Element.up( this, '.cluster' );
      if ( elem && elem.id ){
        var elements = [];
        elem.id.scan(/[^_]+/, function(match) { elements.push(match[0]) });
        location.href = this.href + '?' + elements[0] + '=' + elements[1]
        return false;
      }"
  end
  
  def fb_like_plugin( record, style = "" )
    url = case( record ) when JAPI::Story
      story_path( :id => record, :only_path => false )
    when JAPI::Author
      page_author_path( :id => record, :only_path => false )
    when JAPI::Source
      page_source_path( :id => record, :only_path => false )
    end rescue nil
    render(:partial => "shared/fb_like", :locals => { :url =>  url, :style => style }) if url
  end
  
  def erb_cache(name = {}, options = {}, &block)
    locals = options.delete( :locals )
    content = capture{ cache( name, options, &block) }
    concat( @template.render( :inline => content, :locals => locals ) )
  end
  
  def show_wizard( wizard_id )
    partial = case( wizard_id ) when :random :
      current_user.random_wizard
    when :author, :story, :source, :topic:
      current_user.wizard?( wizard_id ) ? wizard_id : nil
    end
    render :partial => "shared/wizards/#{partial}" if partial
  end
  
  # Singapore Edition 'sg-en' ClusterGroups Exists but Removing Singapore from the list
  def edition_options
    editions= case I18n.locale 
    when 'de', :de : [ 'int-en', 'de-de', 'at-de', 'ch-de', 'in-en', 'gb-en', 'us-en' ]
    else  [ 'int-en', 'in-en', 'gb-en', 'us-en', 'de-de', 'at-de', 'ch-de' ] end
    editions.collect!{ |e| [ I18n.t( "prefs.edition.#{e.split('-').first}"), e ] }
  end
  
  def mouse_over( event_target, &block )
    content = capture do 
      block.call( "mo_#{event_target}_event_src", "mo_#{event_target}" )
    end
    block_called_from_erb?( block ) ? concat( content ) : content
  end
  
  def source_rating_links( source )
    preference_options( :source_rating ).collect{ |option|
      link_to( option.first, rate_source_path( :id => source, :rating => option.last ) )
    }
  end
  
  def author_rating_links( author )
    preference_options( :author_rating ).collect{ |option| 
      link_to( option.first, rate_author_path( :id => author, :rating => option.last ) )
    }
  end
  
  # def mouse_over_menu( &block )
  #    mouse_over_content_tag( block_called_from_erb?(block), 'mo_menu', &block )
  #  end
  #  
  #  def mouse_over_content_tag( concat, class_name, &block )
  #    content = content_tag( :span, :class => "#{class_name}_event_src" ) do
  #      block.call( class_name )
  #    end
  #    concat ? concat( content ) : content
  #  end
  
  def render_rating_stars( author_or_source )
    render :partial => 'shared/rating_stars', :locals => { :average => author_or_source.average_user_preference, :count => author_or_source.user_preference_count, :source => ( author_or_source.is_a?( JAPI::Author ) ? 'author' : 'source' ) }
  end
  
  def render_cluster_preview( cluster, headline = nil )
    headline ||= cluster.stories.shift
    render :partial => 'clusters/preview', :locals => { :headline => headline, :cluster => cluster }
  end
  
  def render_image_block( cluster_or_story, hide_image = false, &block )
    content = ""
    if current_user.show_images? && cluster_or_story.image && !hide_image
      block_content = capture(){ block.call } if block
      content << capture(){ render( :partial => 'shared/image_block', :locals => { :image => cluster_or_story.image, :url => cluster_or_story.url, :content => block_content } ) }
    else
      content << capture(){ block.call } if block
    end
    block_called_from_erb?( block ) ? concat( content ) : content
  end
  
  def render_cluster_info( cluster )
    render :partial => 'clusters/info', :locals => { :cluster => cluster }
  end
  
  def render_story_preview( story, options = nil )
    ( options ||= {} ).reverse_merge( :without => [] )
    options[:without] = Array( options[:without] )
    render :partial => 'stories/preview', :locals => { :story => story, 
      :hide_authors => options[:without].include?( :authors ),
      :hide_add_to_reading_list => options[:without].include?( :add_to_reading_list ),
      :hide_image => options[:without].include?( :image ) }
  end
  
  def render_headline_preview( story, options = nil )
    ( options ||= {} ).reverse_merge( :without => [] )
    options[:without] = Array( options[:without] )
    render :partial => 'stories/headline_preview', :locals => { :story => story, 
      :hide_authors => options[:without].include?( :authors ),
      :hide_add_to_reading_list => options[:without].include?( :add_to_reading_list ),
      :hide_image => options[:without].include?( :image ) }
  end
  
  def render_story_search_preview( story )
    render :partial => 'stories/search_preview', :locals => { :story => story }
  end
  
  def render_pagination( collection )
    render( :partial => 'shared/pagination', :locals => { :pagination => collection.pagination } ) if collection.pagination && collection.pagination.total_pages > 1
  end
  
  def render_search_pagination( collection, options = {} )
    render( :partial => 'stories/pagination', :locals => options.merge( :pagination => collection.pagination ) ) if collection.pagination && collection.pagination.total_pages > 1
  end
  
  def link_to_navigation_item( *args, &block )
    original_args = args.dup
    args.shift if block.nil?
    url_path = url_for( args.first )
    if base_url?( url_path ) then
      content_tag( :span, block ? block.call : original_args.first, :class => 'current' )
    else
      link_to( *original_args, &block )
    end
  end
  
  def link_to_page( title, page )
    page_url = controller.request.url.gsub(/(\?|\&)page\=\d+&?/){ $1 }
    page_url << "?" unless page_url.match(/\?/)
    page_url << "&" unless page_url.match(/(\?|\&)$/)
    page ? link_to( title, "#{page_url}page=#{page}&") : title
  end
  
  def link_to_page_function( title, page )
    page ? link_to_function( title, "pagination_page_click(#{page})" ) : title
  end
  
  def links_to_keywords( *keywords )
    keywords.collect{ |keyword| link_to( keyword, stories_path( :q => keyword ) ) }
  end
  
  def render_search_preference_form( *attributes )
    options = attributes.extract_options!
    render :partial => 'stories/preferences', :locals => options.merge( :attributes => attributes )
  end
  
  def render_cluster_preference_form( *attributes )
    options = attributes.extract_options!
    render :partial => 'clusters/preferences', :locals => options.merge( :attributes => attributes )
  end
  
  def preference_options( attribute, options = {} )
    options[:args] = Array( options[:args] )
    args = [ "#{attribute}_options" ] + options[:args]
    select_options = JAPI::PreferenceOption.send( *args ).collect{ |option| [ t(option.name), option.id ] }
    if options[:include_blank]
      value = options[:include_blank] == true ? '' : t( options[:include_blank] )
      select_options.unshift( [ value, nil ] )
    end
    select_options
  end
  
  def render_category_links( categories, base_url )
    render :partial => 'sources/categories', :locals => { :categories => categories, :base_url => base_url }
  end
  
  def story_symbol( story )
    str = ""
    begin
      str << image_tag( 'video.gif' ) if story.is_video?
      #str << image_tag( 'opinion.gif' ) if story.is_opinion?
    rescue StandardError
    end
    return str
  end
  
  def render_category_link( name, url, category_id )
    if @category_id == category_id
      content_tag( :span, t( name ) )
    else
      url = url + "?" unless url.match(/\?/)
      url = url + "&ctid=#{category_id}" unless category_id == :all
      link_to( t( name ), url )
    end
  end
  
  def render_filter_links( facets, form_url, form_method )
    render :partial => 'shared/filters', :locals => { :facets => facets, :form_url => form_url, :form_method => form_method }
  end
  
  def render_filter_link( filter, name, count )
    return if eval( "@skip_#{filter}_filter" ) || count <= 0
    string = ( filter == :all ) ? '' : " "
    if @filter == filter
      string << " " << content_tag( :span, t( name, :count => count ) )
    else
      string << " " << link_to_function( t( name, :count => count ), "filter_click('#{filter}')")
    end
    return string
  end
  
  #rlb - related link bar
  def render_rlb_filter_link( filter, name, count, html_options = {} )
    return if count <= 0
    link = @more_results_url.dup
    link << "?" unless link.match(/\?/)
    link << "&" unless link.match(/(\?|\&)$/)
    link << "#{filter}=1"
    " - " + link_to( t( name, :count => count ), link , html_options )
  end
  
  def render_author_preview( author )
    render :partial => 'authors/preview', :locals => { :author => author }
  end
  
  def render_author_subscription( author_preference, author )
    render :partial => 'authors/subscription', :locals => { :author => author, :author_preference => author_preference }
  end
  
  def render_author_rating_form( author_preference, author )
    render :partial => 'authors/rating_form', :locals => { :author => author, :author_preference => author_preference }
  end
  
  def render_source_rating_form( source_preference, source )
    render :partial => 'sources/rating_form', :locals => { :source => source, :source_preference => source_preference }
  end
  
  def render_my_author_link( name, link_type, url )
    if ( params[:list] == '1' && link_type == :authors ) || ( params[:list] != '1' && link_type == :stories )
      content_tag( :span, t(name) )
    else
      link_to( t(name), url )
    end
  end
  
  def render_author_filter_links( base_url )
    [ :all, :subscribed, :rated ].collect{ |x| render_author_filter_link( x, base_url ) }.join( " " )
  end
  
  def render_author_filter_link( filter, url )
    if @author_filter == filter
      content_tag( :span, t( "author.filter.#{filter}" ) )
    else
      url = url + "&#{filter}=1" unless filter == :all
      link_to( t( "author.filter.#{filter}" ), url )
    end
  end
  
  def display_only_story_search_results?
    controller.action_name != 'index'
  end
  
  def edit_topic_path( topic )
    url_for_account_server( "users/#{current_user.id}/topic_preferences/#{topic.id}/edit" )
  end
  
  def per_page
    Integer( params[:per_page] || ( current_user.per_page rescue 10 ) || 10 )
  end
  
  def per_page_options
    [ 5, 10, 15, 20, 25, 30 ]
  end
  
  def base_url( url = nil )
    url ||= controller.request.url
    url.gsub(/\?.*/, '')
  end
  
  # Matches whether the current request == navigational url
  def base_url?( url_path )
    @base_url ||= base_url.gsub(/http\:\/\/[^\/]+/, '')
    @base_url == url_path
  end
  
  def page_params( options = {} )
    exclude = Array( options[:exclude] ) + ['controller', 'action', 'ticket', 'locale', 'edition', 'id']
    params.keys.select{ |x| !exclude.include?( x ) }
  end
  
  def to_param( attribute )
    case attribute when :sort_criteria : :sc
    when :cluster_sort_criteria : :sc
    when :subscription_type : :st
    end
  end
  
end
