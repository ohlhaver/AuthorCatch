module StoriesHelper
  
  def request_uri( form_url )
    request_uri = form_url.dup << "?"
    page_params( :exclude => 'per_page' ).collect{ |param| 
      request_uri << "#{param}=#{params[param]}&"
    }
    return request_uri
  end
  
end
