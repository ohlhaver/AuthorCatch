xml.instruct! :xml, :version => "1.0"
xml.rss :version => "2.0" do #, 'xmlns:media' => "http://search.yahoo.com/mrss/" do
  xml.channel do
    xml.title "Jurnalo - Home"
    xml.description I18n.t( 'seo.page.default_title' )
    xml.link root_url( :edition => params[:edition] )
    for block_key in @story_blocks.keys
      blocks = @story_blocks[ block_key ]
      blocks.each do |block|
        if block.respond_to?( :clusters ) && !block.clusters.blank?
          for cluster in block.clusters
            render_rss_for_cluster( cluster, xml, :block => block, :block_key => block_key )
          end
        end
        if block.respond_to?( :stories ) && !block.stories.blank?
          for story in block.stories
            render_rss_for_story( story, xml, :block => block, :block_key => block_key )
          end
        end
      end
    end
  end
end