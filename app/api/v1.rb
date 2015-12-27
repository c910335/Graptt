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
      post :connection do
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
         requires :token, type: String, desc: 'token which returned when connected'
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
         optional :del, type: Boolean, default: 'true', desc: 'true if del the others'
         requires :token, type: String, desc: 'token which returned when connected'
      end
      delete :other do
         error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
         ptt = ptts[params[:token]]
         error! 'Bad Request', 400 if ptt.del_other(params[:del]) == PTT::ERROR
         {status: 'Main Menu'}
      end

      desc 'Get Boards' do
         failure [[404, 'Connection Not Found'], [400, 'Bad Request']]
      end
      params do
         optional :favorite, type: Boolean, default: true, desc: 'true to get favorite boards'
         requires :token, type: String, desc: 'token which returned when connected'
      end
      get :boards do
         error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
         ptt = ptts[params[:token]]
         if params[:favorite]
            boards = ptt.favorites
         else
            error! 'Not Implemented', 501
         end
         error! 'Bad Request', 400 if boards == PTT::ERROR
         boards.each_index { |i| boards[i] = boards[i].to_hash }
         {status: 'Main Menu', boards: boards}
      end

      desc 'Enter a Specific Board' do
         failure [[404, 'Connection Not Found'], [400, 'Bad Request'], [404, 'Board Not Found']]
      end
      params do
         requires :name, type: String, desc: 'en_name of the board to enter'
         requires :token, type: String, desc: 'token which returned when connected'
      end
      put :board do
         error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
         ptt = ptts[params[:token]]
         name = ptt.enter! params[:name]
         case name
         when PTT::ERROR
            error! 'Bad Request', 400
         when PTT::NOT_FOUND
            error! 'Board Not Found', 404
         end
         {status: 'In Board', name: name}
      end

      desc 'Get the Posts of the Next Page in Currently Board' do
         failure [[404, 'Connection Not Found'], [400, 'Bad Request']]
      end
      params do
         requires :token, type: String, desc: 'token which returned when connected'
      end
      get :posts do
         error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
         ptt = ptts[params[:token]]
         posts = ptt.list_posts
         error! 'Bad Request', 400 if posts == PTT::ERROR
         posts.each_index { |i| posts[i] = posts[i].to_hash }
         {status: 'In Board', posts: posts}
      end

      resource :post do

         desc 'Create a New Post' do
            failure [[404, 'Connection Not Found'], [400, 'Bad Request']]
         end
         params do
            requires :token, type: String, desc: 'token which returned when connected'
            requires :title, type: String, desc: 'title of the post'
            requires :content, type: String, desc: 'content of the post'
         end
         post do
            error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
            ptt = ptts[params[:token]]
            error! 'Bad Request', 400 if ptt.post!(params[:title], params[:content]) == PTT::ERROR
            {status: 'In Board'}
         end

         desc 'Return the Specific Post' do
            detail 'no id provided for read more'
            failure [[404, 'Connection Not Found'], [404, 'Post Not Found'], [400, 'Bad Request']]
         end
         params do
            requires :token, type: String, desc: 'token which returned when connected'
            optional :id, type: String, desc: 'id of the post'
         end
         get do
            error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
            ptt = ptts[params[:token]]
            if params[:id].nil?
               post = ptt.post
            else
               post = ptt.post params[:id]
            end
            error! 'Post Not Found', 404 if post == PTT::NOT_FOUND
            error! 'Bad Request', 400 if post == PTT::ERROR
            {status: 'In Post', post: post.to_hash}
         end

         desc 'Set the Specific Post Read' do
            failure [[404, 'Connection Not Found'], [404, 'Post Not Found'], [400, 'Bad Request']]
         end
         params do
            requires :token, type: String, desc: 'token which returned when connected'
            requires :id, type: String, desc: 'id of the post to set read'
            optional :read, type: Boolean, default: true, desc: 'true if set the post read'
         end
         put do
            error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
            ptt = ptts[params[:token]]
            if params[:read]
               status = ptt.read! params[:id]
               error! 'Post Not Found', 404 if status == PTT::NOT_FOUND
               error! 'Bad Request', 400 if status == PTT::ERROR
            else
               error! 'Not Implemented', 501
            end
            {status: 'In Board'}
         end

      end

      desc 'Push the Specific Post' do
         failure [[404, 'Connection Not Found'], [404, 'Post Not Found'], [400, 'Bad Request']]
      end
      params do
         requires :token, type: String, desc: 'token which returned when connected'
         requires :id, type: String, desc: 'id of the post to push'
         requires :tag, type: Integer, values: [1, 2, 3], desc: '1 to push, 2 to boo or 3 for arrow'
         requires :content, type: String, desc: 'content of the push'
      end
      post :push do
         error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
         ptt = ptts[params[:token]]
         error! 'Post Not Found', 404 if ptt.push!(params[:id], params[:tag], params[:content]) == PTT::ERROR
         {status: 'In Board'}
      end

      desc 'Close the Connection' do
         failure [[404, 'Connection Not Found']]
      end
      params do
         requires :token, type: String, desc: 'token which returned when connected'
      end
      delete :connection do
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
