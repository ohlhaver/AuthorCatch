# Nokogiri Bugfix for CDATA elements CAS Authentication Bug
if defined?( ActiveSupport::XmlMini_Nokogiri )

ActiveSupport::XmlMini_Nokogiri::Conversions::Node.class_eval do
  CONTENT_ROOT = '__content__'
  
  def to_hash(hash = {})
    hash[name] ||= attributes_as_hash

    walker = lambda { |memo, parent, child, callback|
      next if child.blank? && 'file' != parent['type']

      if child.text? || child.cdata?
        (memo[CONTENT_ROOT] ||= '') << child.content
        next
      end

      name = child.name

      child_hash = child.attributes_as_hash
      if memo[name]
        memo[name] = [memo[name]].flatten
        memo[name] << child_hash
      else
        memo[name] = child_hash
      end

      # Recusively walk children
      child.children.each { |c|
        callback.call(child_hash, child, c, callback)
      }
    }

    children.each { |c| walker.call(hash[name], self, c, walker) }
    hash
  end
end

Nokogiri::XML::Node.send(:include, ActiveSupport::XmlMini_Nokogiri::Conversions::Node)

end