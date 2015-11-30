class Post
   attr_accessor :id, :num, :author, :title, :date, :status, :like, :source, :url, :pttcoin
   def initialize params
      merge! params
   end
   def merge! params
      params.each do |key, value|
         value = value.force_encoding('big5-uao').encode('utf-8', invalid: :replace, undef: :replace).strip if value.kind_of? String
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
