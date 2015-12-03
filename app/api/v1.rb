module Graptt
   class V1 < Grape::API
      format :json

      helpers do
         def ptts
            @@ptts ||= Hash.new
         end
      end

      desc 'Connect to PTT' do
         failure [[503, 'Overload']]
      end
      post :connect do
         ptt = PTT.new
         error! 'Overload', 503 if ptt.connect! == PTT::OVERLOAD
         token = SecureRandom.hex
         ptts[token] = ptt
         {status: 'Connected', token: token}
      end

      desc 'Login PTT' do
         failure [[404, 'Connection Not Found'], [400, 'Bad Reequest'], [503, 'Overload'], [401, 'Login Failed']]
      end
      params do
         requires :account, type: String, desc: 'PTT account'
         requires :password, type: String, desc: 'PTT password'
         requires :token, type: String, desc: 'token which returned when connect'
      end
      put :login do
         error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
         ptt = ptts[params[:token]]
         case ptt.login! params[:account], params[:password]
         when PTT::ERROR
            error! 'Bad Request', 400
         when PTT::OVERLOAD
            ptts.delete params[:token]
            error! 'Overload', 503
         when PTT::LOGIN_FAIL
            ptts.delete params[:token]
            error! 'Login Failed', 401
         when PTT::OTHER_ONLINE
            status = 'Other Online'
         else
            status = 'Main Menu'
         end
         {status: status}
      end

      desc 'Delete the Other Same Account Online' do
         failure [[404, 'Connection Not Found'], [400, 'Bad Request']]
      end
      params do
         optional :del, type: Boolean, default: 'true', desc: 'True if del the others'
         requires :token, type: String, desc: 'token which returned when connect'
      end
      delete :other do
         error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
         ptt = ptts[params[:token]]
         error! 'Bad Request', 400 if ptt.del_other(params[:del]) == PTT::ERROR
         {status: 'Main Menu'}
      end

      desc 'Get the Favorites Boards' do
         failure [[404, 'Connection Not Found'], [400, 'Bad Request']]
      end
      params do
         requires :token, type: String, desc: 'token which returned when connect'
      end
      get :favorites do
         error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
         ptt = ptts[params[:token]]
         favorites = ptt.favorites
         error! 'Bad Request', 400 if favorites == PTT::ERROR
         favorites.each_index { |i| favorites[i] = favorites[i].to_hash }
         {status: 'Main Menu', favorites: favorites}
      end

      desc 'Enter a Specific Board' do
         failure [[404, 'Connection Not Found'], [400, 'Bad Request'], [404, 'Board Not Found']]
      end
      params do
         requires :board, type: String, desc: 'en_name of the board to enter'
         requires :token, type: String, desc: 'token which returned when connect'
      end
      put :enter do
         error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
         ptt = ptts[params[:token]]
         board = ptt.enter! params[:board]
         case board
         when PTT::ERROR
            error! 'Bad Request', 400
         when PTT::NOT_FOUND
            error! 'Board Not Found', 404
         end
         {status: 'In Board', board: board}
      end

      desc 'Get the Posts of the Next Page in Currently Board' do
         failure [[404, 'Connection Not Found'], [400, 'Bad Request']]
      end
      params do
         requires :token, type: String, desc: 'token which returned when connect'
      end
      get :posts do
         error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
         ptt = ptts[params[:token]]
         posts = ptt.list_posts
         error! 'Bad Request', 400 if posts == PTT::ERROR
         posts.each_index { |i| posts[i] = posts[i].to_hash }
         {status: 'In Board', posts: posts}
      end

      desc 'Set the Specific Post Read' do
         failure [[404, 'Connection Not Found'], [404], 'Post Not Found']
      end
      params do
         requires :token, type: String, desc: 'token which returned when connect'
         requires :id, type: String, desc: 'id of the post to set read'
      end
      put :read do
         error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
         ptt = ptts[params[:token]]
         error! 'Post Not Found', 404 if ptt.read!(params[:id]) == PTT::NOT_FOUND
         {status: 'In Board'}
      end

      desc 'Close the Connection' do
         failure [[404, 'Connection Not Found']]
      end
      params do
         requires :token, type: String, desc: 'token which returned when connect'
      end
      delete :connect do
         error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
         ptt = ptts[params[:token]]
         ptt.close!
         ptts.delete params[:token]
         {status: 'Bye Bye'}
      end

      add_swagger_documentation api_version: 'v1',
                                hide_documentation_path: true,
                                hide_format: true,
                                mount_path: '/doc',
                                base_path: "#{Settings::API_URL}/graptt/v1"
   end
end
