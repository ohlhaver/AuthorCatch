xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do #, 'xmlns:media' => "http://search.yahoo.com/mrss/" do
  xml.channel do
    xml.title @page_title
    xml.link stories_url( @param_options.merge( :edition => params[:edition], :locale => params[:locale] ) )
    for story in @stories
      render_rss_for_story( story, xml )
    end
  end
end