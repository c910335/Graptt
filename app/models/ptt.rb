require 'net/telnet'
require './app/models/terminal'
require './app/models/board'
require './app/models/post'

def big5 string
      string.encode('big5-uao')
end
def telcode string
      big5(string).force_encoding('ASCII-8BIT')
end

class PTT
   OK = 0
   ERROR = 1
   OVERLOAD = 2
   LOGIN_FAIL = 3
   OTHER_ONLINE = 4
   NOT_FOUND = 5

   NOT_CONNECT = 10
   CONNECTED = 11
   TO_DEL_OTHER = 12
   MAIN_MENU = 13
   IN_BOARD = 14

   attr_reader :status

   def initialize
      @terminal = Terminal.new
      @status = NOT_CONNECT
   end

   def connect!
      @ptt = Net::Telnet.new({'Host' => 'ptt.cc', 'Port' => 443})
      waitfor '(new 註冊:|系統過載)'
      if @terminal[13].match telcode '系統過載'
         close!
         return OVERLOAD
      end
      @status = CONNECTED
      OK
   end

   def login! account, password
      return ERROR if @status != CONNECTED
      @ptt.puts ' ' + account
      waitfor '(密碼)|(沒有這個)|(重新輸入)'
      if @terminal[21].match telcode '(沒有這個)|(重新輸入)'
         close!
         return LOGIN_FAIL
      end
      @ptt.puts password
      waitfor '(連往本站。)|(您想刪除其他重複登入的連線嗎？)|(系統過載)|(刪除以上錯誤嘗試)'
      if @terminal[22].match telcode '您想刪除其他重複登入的連線嗎？'
         @status = TO_DEL_OTHER
         return OTHER_ONLINE
      elsif @terminal[22].match telcode '系統過載'
         close!
         return OVERLOAD
      elsif @terminal[22].match telcode '密碼不對'
         close!
         return LOGIN_FAIL
      elsif @terminal[23].match telcode '刪除以上錯誤嘗試'
         @ptt.puts 'Y'
      end
      @ptt.print 'q'
      waitfor '離開，再見'
      @status = MAIN_MENU
      OK
   end

   def close!
      @ptt.close
      @status = NOT_CONNECT
      OK
   end

   def del_other d = true
      return ERROR if @status != TO_DEL_OTHER
      if d
         @ptt.puts 'Y'
      else
         @ptt.puts 'n'
      end
      waitfor '連往本站。'
      @ptt.print 'q'
      waitfor '離開，再見'
      @status = MAIN_MENU
      OK
   end

   def favorites
      return ERROR if @status != MAIN_MENU && @status != IN_BOARD
      @ptt.puts 'qqqqqqqqqqf'
      waitfor '[A-Za-z]'
      next_page = true
      boards = []
      while next_page
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
         @ptt.print "\e[6~"
         waitfor '[A-Za-z]'
         if @terminal[3][0] == ' '
            next_page = false
            break
         end
      end
      @ptt.print 'q'
      waitfor '離開，再見'
      @status = MAIN_MENU
      boards
   end

   def enter! board
      return ERROR if @status != MAIN_MENU && @status != IN_BOARD
      board = board.en_name if board.kind_of? Board
      @ptt.puts 'qqqqqqqqqqs' + board
      sleep 1
      waitfor '.*'
      if @terminal[23].match telcode '呼叫器'
         return NOT_FOUND
      elsif @terminal[23].match telcode '任意鍵繼'
         @ptt.puts ''
         waitfor '進板畫面'
      end
      @ptt.print "\e[1~\e[4~"
      @row = 22
      @status = IN_BOARD
      OK
   end

   def list_posts
      return ERROR if @status != IN_BOARD
      posts = []
      while true
         post = Post.new({
            num: @terminal[@row][2..6].to_i,
            author: @terminal[@row][17..28],
            title: @terminal[@row][33..78],
            date: @terminal[@row][11..15],
            status: @terminal[@row][8],
            like: @terminal[@row][9..10],
            source: @terminal[@row][30..31]
         })
         if @terminal[@row][17] != '-' && @terminal[@row][18] != ' '
            @ptt.print 'Q'
            waitfor '#'
            if @row > 14
               post.merge!({
                  id: @terminal[@row - 4][18..26],
                  url: @terminal[@row - 3][13..74],
                  pttcoin: @terminal[@row - 2][16..24].to_i
               })
            else
               post.merge!({
                  id: @terminal[@row + 2][18..26],
                  url: @terminal[@row + 3][13..74],
                  pttcoin: @terminal[@row + 4][16..24].to_i
               })
            end
            @ptt.print "\e[C"
            waitfor '進板畫面'
         end
         posts << post
         @ptt.print "\e[A"
         @row -= 1
         if @row <= 2
            sleep 1
            waitfor '.*'
            @row = 21
            break
         end
      end
      posts
   end

   def waitfor string
      @ptt.waitfor(/#{telcode string}/) { |s| @terminal.print s }
      # puts @terminal
   end

   def to_s
      @terminal.to_s
   end
end
