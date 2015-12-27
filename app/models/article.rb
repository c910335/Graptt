class Article
   attr_accessor :id, :author, :title, :time, :url, :pttcoin, :content, :end

   def initialize params
      merge! params
      @end = false
   end

   def merge! params
      params.each do |key, value|
         value = value.to_utf8.strip if value.kind_of? String
         instance_variable_set("@#{key}", value)
      end
   end

   def push_content row
      match_data = row.match '^(推|→|噓) ([a-zA-Z\d]*):(.*)(\d\d/\d\d \d\d:\d\d)  $'.telcode
      if match_data
         @content << Article::Push.new(match_data[1], match_data[2], match_data[3], match_data[4])
      else
         @content << row.to_utf8
      end
   end

   def content_raw
      raw = ''
      if @content.kind_of? Array
         @content.each do |row|
            raw << row.to_s
         end
      end
   end

   def strip
      while @content[-1].kind_of?(String) && @content[-1].match(' ' * 80)
         @content.pop
      end
   end

   def to_hash
      hash = Hash.new
      instance_variables.each do |key|
         if key == :@content
            hash['content'] = []
            @content.each do |row|
               if row.kind_of? String
                  hash['content'] << row.rstrip
               else
                  hash['content'] << row.to_hash
               end
            end
         else
            hash[key[1..-1]] = instance_variable_get key
         end
      end
      hash
   end

   def to_s
      to_hash.to_s
   end

   class Push
      attr_accessor :tag, :author, :content, :time
      def initialize tag, author, content, time
         @tag = tag.to_utf8.strip
         @author = author.to_utf8.strip
         @content = content.to_utf8
         @time = time.to_utf8.strip
      end

      def to_hash
         {tag: @tag, author: @author, content: @content.strip, time: @time}
      end

      def to_s
         s = @tag + ' ' + @author + ':' + @content + @time
      end
   end
end
