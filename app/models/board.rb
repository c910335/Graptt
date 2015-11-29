class Board
   attr_accessor :num, :en_name, :zh_name, :unread, :type, :popularity
   def initialize params
      params.each do |key, value|
         value = value.force_encoding('big5-uao').encode('utf-8', invalid: :replace, undef: :replace).strip if value.kind_of? String
         value -= 1 if key == :num
         instance_variable_set("@#{key}", value)
      end
   end
   def to_hash
      hash = Hash.new
      instance_variables.each { |key| hash[key[1..-1]] = instance_variable_get key }
      hash
   end
   def to_s
      to_hash.to_s
   end
end
