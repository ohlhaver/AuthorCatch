String.class_eval do
  
  EXTENDED_ASCII_MAP = [
     67, 117, 101,  97,  97,  97,  97, 99, 
    101, 101, 101, 105, 105, 105,  65, 65, 
     69,   [ 97, 101 ],     [ 65, 69], 111, 
    111, 111, 117, 117,  95,  79,  85, nil,
    nil,  95, 102,  97, 105, 111, 117, 110, 
    78 
  ]
  #
  # Converstion maps for accented chars to their equivalents
  # Starting from offset 222
  #
  EXTENDED_ASCII_MAP2 = [ nil, [115, 115] ]
  
  # Assumes string is in UTF-8
  def to_ascii_s
    chars = self.mb_chars.normalize(:kd).unpack('U*')
    chars.collect! do |char| 
      case( char )
      when 0..127 : char
      when 128..221 : EXTENDED_ASCII_MAP[ char-128 ]
      when 222..255 : EXTENDED_ASCII_MAP2[ char-222 ]
      else nil end
    end
    chars.flatten!
    chars.delete_if{ |x| x.nil? }
    chars.pack('C*')
  end
  
end