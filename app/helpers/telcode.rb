class String
   def big5
      self.encode 'big5-uao'
   end
   def telcode
      self.big5.to_ascii.gsub "\x9DA".to_ascii,"\xA1\xF7".to_ascii
   end
   def to_ascii
      self.force_encoding 'ASCII-8BIT'
   end
   def to_utf8
      String.new(self).force_encoding('big5-uao').encode('utf-8', invalid: :replace, undef: :replace)
   end
end
