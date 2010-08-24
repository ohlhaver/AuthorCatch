module Curb
  
  USER_AGENT = "japi http:://www.jurnalo.com"
  
  AUTH_TYPES = {
    :basic => 1,
    :digest => 2,
    :gssnegotiate => 4,
    :ntlm => 8,
    :digest_ie => 16
  }
      
  def self.open( url, options = {}, &block )
    retries = options.delete(:retries)
    retry_grace = options.delete(:retry_grace)
    return self.open_without_retries( url, options, &block ) unless retries
    response, message = nil, nil
    retries.times do
      begin
        response = open_without_retries( url, options.dup, &block)
      rescue Exception => message
      end
      break if response
      sleep( retry_grace ) if retry_grace
    end
    response.nil? ? raise( message ) : response 
  end
  
  def self.async_post( url, data = "", options = {}, &block )
    multi_curb = options.delete( :multi_curb )
    catch_errors = options.delete(:catch_errors)
    easy = Curl::Easy.new(url) do |curl|
      curl.headers["User-Agent"] = (options[:user_agent] || USER_AGENT)
      curl.follow_location = false
      curl.userpwd = options[:http_authentication].join(':') if options.has_key?(:http_authentication)
      curl.http_auth_types = Array( options[:http_auth] ).collect{ |r| AUTH_TYPES[r] }.inject(0){|s,r| s = s | r } if options.has_key?( :http_auth )
      curl.max_redirects = 0
      curl.timeout = 15 # wait for 10 seconds.
      curl.connect_timeout = 30 # wait for 30 seconds.
      curl.post_body = data
      curl.on_complete{ |easy_curl, code| block.call(easy_curl) } if block
    end
    multi_curb.add( easy )
  end
  
  def self.post( url, data = "", options = {}, &block )
    catch_errors = options.delete(:catch_errors)
    easy = Curl::Easy.new(url) do |curl|
      curl.headers["User-Agent"] = (options[:user_agent] || USER_AGENT)
      curl.headers["If-Modified-Since"] = options[:if_modified_since].httpdate if options.has_key?(:if_modified_since)
      curl.headers["If-None-Match"] = options[:if_none_match] if options.has_key?(:if_none_match)
      curl.headers["Accept-encoding"] = 'gzip, deflate' if options.has_key?(:compress)
      curl.follow_location = true
      curl.userpwd = options[:http_authentication].join(':') if options.has_key?(:http_authentication)
      curl.http_auth_types = Array( options[:http_auth] ).collect{ |r| AUTH_TYPES[r] }.inject(0){|s,r| s = s | r } if options.has_key?( :http_auth )
      curl.max_redirects = options[:max_redirects] if options[:max_redirects]
      curl.timeout = options[:timeout] if options[:timeout]
      curl.connect_timeout = options[:connect_timeout] if options[:connect_timeout]
    end
    success, message = true, ''
    begin
      easy.http_post( data )
    rescue Exception => message
      easy = false
      success = false
    end
    raise message unless success || catch_errors
    block.call( easy ) if block && easy
    return easy
  end
  
  def self.open_without_retries( url, options = {}, &block )
    catch_errors = options.delete(:catch_errors)
    html_only = options.delete( :html_only )
    easy = Curl::Easy.new(url) do |curl|
      curl.headers["User-Agent"] = (options[:user_agent] || USER_AGENT)
      curl.headers["If-Modified-Since"] = options[:if_modified_since].httpdate if options.has_key?(:if_modified_since)
      curl.headers["If-None-Match"] = options[:if_none_match] if options.has_key?(:if_none_match)
      curl.headers["Accept-encoding"] = 'gzip, deflate' if options.has_key?(:compress)
      curl.follow_location = true
      curl.userpwd = options[:http_authentication].join(':') if options.has_key?(:http_authentication)
      curl.http_auth_types = Array( options[:http_auth] ).collect{ |r| AUTH_TYPES[r] }.inject(0){|s,r| s = s | r } if options.has_key?( :http_auth )
      curl.max_redirects = options[:max_redirects] if options[:max_redirects]
      curl.timeout = options[:timeout] if options[:timeout]
      curl.connect_timeout = options[:connect_timeout] if options[:connect_timeout]
    end
    success, message = true, ''
    begin
      perform = true
      if html_only
        req = Curl::Easy.new(url) do |curl|
          curl.headers["User-Agent"] = (options[:user_agent] || USER_AGENT)
          curl.headers["If-Modified-Since"] = options[:if_modified_since].httpdate if options.has_key?(:if_modified_since)
          curl.headers["If-None-Match"] = options[:if_none_match] if options.has_key?(:if_none_match)
          curl.headers["Accept-encoding"] = 'gzip, deflate' if options.has_key?(:compress)
          curl.follow_location = true
          curl.userpwd = options[:http_authentication].join(':') if options.has_key?(:http_authentication)
          curl.http_auth_types = Array( options[:http_auth] ).collect{ |r| AUTH_TYPES[r] }.inject(0){|s,r| s = s | r } if options.has_key?( :http_auth )
          curl.max_redirects = options[:max_redirects] if options[:max_redirects]
          curl.timeout = options[:timeout] if options[:timeout]
          curl.connect_timeout = options[:connect_timeout] if options[:connect_timeout]
        end
        req.http_head
        perform = !req.content_type.match(/(html)|(xml)/).nil?
      end
      easy.perform if perform
    rescue Exception => message
      easy = false
      success = false
    end
    raise message unless success || catch_errors
    block.call( easy ) if block && easy
    return easy
  end
  
end
