class Terminal
   attr_reader :width, :height, :content, :color

   def initialize width = 80, height = 24, in_encode = 'big5-uao', out_encode = 'utf-8'
      @width = width
      @height = height
      @in_encode = in_encode
      @out_encode = out_encode
      @content = Array.new(height) { " " * width }
      @row = 0
      @column = 0
   end

   def [] this_row
      @content[this_row]
   end

   def to_s
      s = ''
      @content.each {|i| s << String.new(i).force_encoding(@in_encode).encode('utf-8', invalid: :replace, undef: :replace) + "\n"}
      s
   end

   def print string
      string = string.force_encoding 'ASCII-8BIT'
      escape = false
      escape_num = 0
      escape_nums = [0]
      string.each_char do |char|
         if escape
            if char == '['
               next
            elsif char[/\d/]
               escape_num = escape_num * 10 + char.to_i
            elsif char == ';'
               escape_nums << escape_num
               escape_num = 0
            else
               case char
               when 'A'
                  up escape_num
               when 'B'
                  down escape_num
               when 'C'
                  forward escape_num
               when 'D'
                  back escape_num
               when 'E'
                  next_line escape_num
               when 'F'
                  previous_line escape_num
               when 'G'
                  move_column escape_num
               when 'H', 'f'
                  move escape_nums[-1], escape_num
               when 'J'
                  erase escape_num
               when 'K'
                  erase_line escape_num
               when 'S'
                  scroll_up escape_num
               when 'T'
                  scroll_down escape_num
               end
               escape = false
               escape_num = 0
               escape_nums = [0]
            end
         else
            case char
            when "\e"
               escape = true
            when "\n"
               next_line
            when "\b"
               back
            else
               set char
            end
         end
      end
   end

   # \e\[\d*A
   def up dis = 1
      dis = 1 if dis == 0
      @row -= dis
      @row = 0 if @row < 0
   end

   # \e\[\d*B
   def down dis = 1
      dis = 1 if dis == 0
      @row += dis
      @row = height - 1 if @row >= height
   end

   # \e\[\d*C
   def forward dis = 1
      dis = 1 if dis == 0
      @column += dis
      @column = width - 1 if @column >= width
   end

   # \e\[\d*D
   def back dis = 1
      dis = 1 if dis == 0
      @column -= dis
      @column = 0 if @column < 0
   end

   # \e\[\d*E
   def next_line dis = 1
      dis = 1 if dis == 0
      down dis
      back width
   end

   # \e\[\d*F
   def previous_line dis = 1
      dis = 1 if dis == 0
      up dis
      back width
   end

   def move_z new_row, new_column
      @row = new_row
      @column = new_column
   end

   # \e\[\d*[G]
   def move_column new_column
      new_column = 1 if new_column < 1
      move_z row, new_column - 1
   end

   # \e\[[\d;]*[Hf]
   def move new_row, new_column
      new_row = 1 if new_row < 1
      new_column = 1 if new_column < 1
      move_z new_row - 1, new_column - 1
   end

   # \e\[[012]*J
   def erase where, erase_row = @row, erase_column = @column
      case
      when 0
         ((erase_row + 1)...height).each { |i| @content[i] = ' ' * width }
         erase_line 0, erase_row, erase_column
      when 1
         (0...erase_row).each { |i| @content[i] = ' ' * width }
         erase_line 1, erase_row, erase_column
      when 2
         @content = Array.new(height) { ' ' * width }
         move_z 0, 0
      end
   end

   # \e\[[012]*K
   def erase_line where, erase_row = @row, erase_column = @column
      case
      when 0
         @content[erase_row][erase_column...width] = ' ' * (width - erase_column)
      when 1
         @content[erase_row][0...erase_column] = ' ' * erase_column
      when 2
         @content[erase_row] = ' ' * width
      end
   end

   # \e\[\d*S
   def scroll_up dis = 1
      dis = 1 if dis == 0
      dis = height if dis > height
      (0...(height - dis)).each { |i| @content[i] = @content[i + dis] }
      erase 0, height - dis, 0
   end

   # \e\[\d*T
   def scroll_down dis = 1
      dis = 1 if dis == 0
      dis = height if dis > height
      (dis...(height - 1)).each { |i| @content[i] = @content[i - dis] }
      erase 1, dis - 1, width
   end

   # \e\[s
   def save_pos
      @saved_row = @row
      @saved_column = @column
   end

   # \e\[u
   def restore_pos
      @row = @saved_row
      @column = @saved_column
   end

   def set char
      @content[@row][@column] = char
      @column += 1
      @column = width - 1 if @column >= width
   end
end
