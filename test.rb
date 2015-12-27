require './app/helpers/telcode'
require './app/models/ptt'

f = true
while f
   while true
      ptt = PTT.new
      if ptt.connect! == PTT::OVERLOAD
         puts '系統過載G_G'
         sleep 1
         next
      end
      break
   end

   print '帳號: '
   account = gets.chomp
   print "密碼: \e[30m"
   password = gets.chomp
   print "\e[m"

   case ptt.login! account, password
   when PTT::OVERLOAD
      puts '系統過載G_G'
   when PTT::LOGIN_FAIL
      puts '打錯囉你看看你'
   when PTT::OTHER_ONLINE
      print '刪除其他登入？[Y/n]: '
      del = gets[0]
      ptt.del_other !(del == 'n' || del == 'N')
      f = false
   else
      f = false
   end
end

favorites = ptt.favorites
puts favorites

while true
   while true
      print '進入: '
      board = gets.chomp
      board = ptt.enter! board
      break if board != PTT::NOT_FOUND
      puts '查無此看板'
   end
   cmd = 'j'
   while true
      break if cmd == 'q' || cmd == 'Q'
      case cmd
      when 'j', 'J'
         posts = ptt.list_posts
         puts posts
      when 'p', 'P'
         print '標題: '
         title = gets
         print '內容: '
         content = gets
         ptt.post! title, content
      when 'l', 'L'
         print '進入: '
         article = ptt.post gets.chomp
         while true
            break if article == PTT::ERROR || article == PTT::NOT_FOUND
            puts article
            puts article.content_raw
            print '(j)下一頁 (q)離開文章: '
            cmd = gets[0]
            break if cmd != 'j' && cmd != 'J'
            article = ptt.post
         end
      end
      print '(j)下一頁 (p)發表文章 (l)閱讀文章 (q)離開看板: '
      cmd = gets[0]
   end
end
