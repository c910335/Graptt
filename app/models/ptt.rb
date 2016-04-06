require 'net/telnet'
require './app/models/terminal'
require './app/models/board'
require './app/models/post'
require './app/models/article'

class PTT

   IN_PTT = [:main_menu, :in_board, :in_post]

   attr_reader :status

   def initialize
      @terminal = Terminal.new
      @status = :not_connect
   end

   def connect!
      @ptt = Net::Telnet.new({'Host' => 'ptt.cc', 'Port' => 443})
      waitfor 'new 註冊:|系統過載'
      if @terminal[13].match '系統過載'.telcode
         close!
         return :overload
      end
      @status = :connected
      :ok
   end

   def login! account, password
      return :error unless @status == :connected
      @ptt.puts ' ' + account
      waitfor '密碼|沒有這個|重新輸入'
      if @terminal[21].match '沒有這個|重新輸入'.telcode
         close!
         return :login_fail
      end
      @ptt.puts password
      waitfor '連往本站。|您想刪除其他重複登入的連線嗎？|系統過載|重新輸入|密碼不對'
      if @terminal[22].match '您想刪除其他重複登入的連線嗎？'.telcode
         @status = :to_del_other
         return :other_online
      elsif @terminal[21].match '密碼不對|重新輸入'.telcode
         close!
         return :login_fail
      elsif @terminal[22].match '系統過載'.telcode
         close!
         return :overload
      end
      @ptt.print 'q'
      waitfor '離開，再見|刪除以上|文章尚未'
      if @terminal[23].match '刪除以上'.telcode
         @ptt.puts 'Y'
         waitfor '離開，再見'
      elsif @terminal[1].match '文章尚未'.telcode
         @ptt.puts 'Q'
         waitfor '離開，再見'
      end
      @status = :main_menu
      :ok
   end

   def close!
      @ptt.close
      @status = :not_connect
      :ok
   end

   def del_other d = true
      return :error unless @status == :to_del_other
      if d
         @ptt.puts 'Y'
      else
         @ptt.puts 'n'
      end
      waitfor '連往本站。'
      @ptt.print 'q'
      waitfor '離開，再見|刪除以上'
      if @terminal[23].match '刪除以上'.telcode
         @ptt.puts 'Y'
         waitfor '離開，再見'
      end
      @status = :main_menu
      :ok
   end

   def favorites
      return :error unless IN_PTT.include? @status
      @ptt.print "qqqqqqqqqqf\n\e[1~"
      waitfor '入已知板'
      next_page = true
      boards = []
      loop do
         @terminal[3..22].each do |row|
            if row[6] == ' '
               next_page = false
               break
            end
            boards << Board.new({
               num: row[2..6].chomp.to_i,
               en_name: row[10..21],
               zh_name: row[30..62],
               popularity: row[64..66],
               type: row[23..26],
               unread: row[8..9] != '  '
            })
         end
         break unless next_page
         @ptt.print "\e[6~"
         waitfor '[A-Za-z_>●]'
         if @terminal[3][0] == ' '
            next_page = false
            break
         end
      end
      @ptt.print 'q'
      waitfor '離開，再見'
      @status = :main_menu
      boards
   end

   def enter! board
      return :error unless IN_PTT.include? @status
      return :not_found unless board.match /^[a-zA-Z\d\-_\.]*$/
      board = board.en_name if board.kind_of? Board
      if @status == :in_board
         @ptt.print 'qqqqqqqq'
         waitfor '呼叫器'
      end
      @status = :main_menu
      @ptt.print 's' + board + ' '
      waitfor '.*'
      @ptt.puts ''
      waitfor '呼叫器|任意鍵繼|標題/作|動畫播放中'
      if @terminal[23].match '呼叫器'.telcode
         return :not_found
      elsif @terminal[23].match '動畫播放中'.telcode
         waitfor '任意鍵繼'
         @ptt.puts ''
         waitfor '標題/作'
      elsif @terminal[23].match '任意鍵繼'.telcode
         @ptt.puts ''
         waitfor '標題/作'
      end
      @terminal[0].match '看板《(.*)》'.telcode do |match_data|
         board = match_data[1]
      end
      @last_post = nil
      @status = :in_board
      board
   end

   def list_posts
      leave_post
      return :error unless @status == :in_board
      @ptt.print "\e[A"
      waitfor '●|>'
      @ptt.print "\e[4~\e[B"
      waitfor '●|>'
      unless @last_post.nil?
         @ptt.print @last_post + "\n\e[A"
         waitfor '●|>'
         @post_shift.times do
            @ptt.print "\e[A"
            waitfor '●|>'
         end
      end
      posts = []
      row = @terminal.row
      while true
         post = Post.new({
            num: @terminal[row][2..6].to_i,
            author: @terminal[row][17..28],
            title: @terminal[row][33..78],
            date: @terminal[row][11..15],
            status: @terminal[row][8],
            like: @terminal[row][9..10],
            source: @terminal[row][30..31]
         })
         if @terminal[row][17] != '-' && @terminal[row][18] != ' '
            @ptt.print 'Q'
            waitfor '#'
            if row > 14
               post.merge!({
                  id: @terminal[row - 4][18..26],
                  url: @terminal[row - 3][13..74],
                  pttcoin: @terminal[row - 2][16..24].to_i
               })
            else
               post.merge!({
                  id: @terminal[row + 2][18..26],
                  url: @terminal[row + 3][13..74],
                  pttcoin: @terminal[row + 4][16..24].to_i
               })
            end
            @last_post = post.id
            @post_shift = 0
            @ptt.print "\e[C"
            waitfor '進板畫面'
         else
            @post_shift += 1
         end
         posts << post
         @ptt.print "\e[A"
         waitfor '●|>'
         row -= 1
         break if row <= 2
      end
      posts
   end

   def read! post_id
      leave_post
      return :error unless @status == :in_board
      return :not_found if post_id.nil? || ! post_id.match(/^\#[a-zA-Z\d\.\-_]*$/)
      @ptt.puts post_id
      waitfor '不到這個文| '
      if @terminal[22].match '不到這個文'.telcode
         @ptt.print 'q'
         waitfor '.*'
         :not_found
      else
         @ptt.print "\e[C\e[D"
         waitfor '.*'
         :ok
      end
   end

   def post post_id = nil
      if post_id
         leave_post
         return :error unless @status == :in_board
         return :not_found if post_id.nil? || ! post_id.match(/^\#[a-zA-Z\d\.\-_]*$/)
         @ptt.puts post_id
         waitfor "\e.*H"
         if @terminal[22].match '不到這個文'.telcode
            @ptt.print 'q'
            waitfor '.*'
            return :not_found
         else
            row = @terminal.row
            @article = Article.new({
               author: @terminal[row][17..28],
               title: @terminal[row][33..78]
            })
            @ptt.print 'Q'
            waitfor '#'
            if row > 14
               @article.merge!({
                  id: @terminal[row - 4][18..26],
                  url: @terminal[row - 3][13..74],
                  pttcoin: @terminal[row - 2][16..24].to_i
               })
            else
               @article.merge!({
                  id: @terminal[row + 2][18..26],
                  url: @terminal[row + 3][13..74],
                  pttcoin: @terminal[row + 4][16..24].to_i
               })
            end
            @ptt.print "q\e[C"
            waitfor '推文|可播放的'
            if @terminal[23].match '可播放的'.telcode
               @ptt.print "n"
               waitfor '推文'
            end
            row = 0
            if @terminal[3].match ('─' * 39).telcode
               @article.merge!({
                  author: @terminal[0][7..56],
                  title: @terminal[1][7..70],
                  time: @terminal[2][7..70]
               })
               row = 4
            end
            @article.content = []
            while row < 23
               @article.push_content @terminal[row]
               row += 1
            end
            match_data = @terminal[23].match '\( {0,2}(\d+)%\)'.telcode
            if match_data.nil? || match_data[1].to_i == 100
               @article.end = true
               @article.strip
            end
         end
         @status = :in_post
      end
      return :error unless @status == :in_post
      @article.content = [] if post_id.nil?
      return @article if @article.end
      100.times do
         match_data = @terminal[23].match '\( {0,2}(\d+)%\)'.telcode
         if match_data.nil? || match_data[1].to_i == 100
            @article.end = true
            break
         end
         @ptt.print "\e[B"
         waitfor '\d'
         @article.push_content @terminal[22]
      end
      @status = :in_post
      return @article
   end

   def post! title, content
      return :error unless @status == :in_board
      @ptt.print "\C-p"
      waitfor '種類'
      @ptt.puts ""
      waitfor '標題'
      @ptt.puts title.telcode
      waitfor '輯文'
      @ptt.print (content + "\C-x").telcode
      waitfor '定要儲存檔'
      @ptt.print "S\C-c\C-c\C-c"
      waitfor '●|>'
   end

   def push! post_id, push_tag, content
      leave_post
      return :error unless @status == :in_board
      return :not_found if post_id.nil? || ! post_id.match(/^\#[a-zA-Z\d\.\-_]*$/)
      @ptt.puts post_id
      waitfor "\e.*H"
      if @terminal[22].match '不到這個文'.telcode
         @ptt.print 'q'
         waitfor '.*'
         :not_found
      else
         @ptt.print 'X'
         waitfor '\d|→'
         if @terminal[23].match '覺得這篇文'.telcode
            @ptt.print push_tag.to_s
            waitfor '→|推|噓'
         end
         @ptt.puts content.telcode
         waitfor '確定'
         @ptt.puts 'y'
         waitfor '.*'
         :ok
      end
   end

   def leave_post
      if @status == :in_post
         @ptt.print "\e[D"
         waitfor '●|>'
         @status = :in_board
      end
   end

   def waitfor string
      @ptt.waitfor(/#{string.telcode}/) { |s| @terminal.print s }
      # puts @terminal
   end

   def to_s
      @terminal.to_s
   end
end
