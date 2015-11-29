require './app/models/ptt'

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
   exit
when PTT::LOGIN_FAIL
   puts '打錯囉你看看你'
   exit
when PTT::OTHER_ONLINE
   print '刪除其他登入？[Y/n]: '
   del = gets[0]
   ptt.del_other !(del == 'n' || del == 'N')
end

favorites = ptt.favorites
puts favorites

while true
   while true
      print '進入: '
      board = gets.chomp
      break if ptt.enter!(board) != PTT::NOT_FOUND
      puts '查無此看板'
   end
   list = 'Y'
   while list != 'n' && list != 'N'
      posts = ptt.list_posts
      puts posts
      print '下一頁？[Y/n]: '
      list = gets[0]
   end
end
