module Graptt
   class V1 < Grape::API
      format :json
      content_type :json, 'application/json;charset=UTF-8'

      helpers do
         def ptts
            @@ptts ||= Hash.new
         end
      end

      resource :connection do
         desc 'Connect to PTT' do
            failure [[503, 'Overload']]
         end
         post do
            ptt = PTT.new
            error! 'Overload', 503 if ptt.connect! == :overload
            token = SecureRandom.urlsafe_base64
            ptts[token] = ptt
            {status: 'Connected', token: token}
         end

         route_param :token do

            desc 'Close the Connection' do
               failure [[404, 'Connection Not Found']]
            end
            params do
               requires :token, type: String, desc: 'token which returned when connected'
            end
            delete do
               error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
               ptt = ptts[params[:token]]
               ptt.close!
               ptts.delete params[:token]
               {status: 'Bye Bye'}
            end

            desc 'Login PTT' do
               failure [[404, 'Connection Not Found'], [400, 'Bad Reequest'], [503, 'Overload'], [401, 'Login Failed']]
            end
            params do
               requires :account, type: String, desc: 'PTT account'
               requires :password, type: String, desc: 'PTT password'
               requires :token, type: String, desc: 'token which returned when connected'
            end
            post :login do
               error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
               ptt = ptts[params[:token]]
               case ptt.login! params[:account], params[:password]
               when :error
                  error! 'Bad Request', 400
               when :overload
                  ptts.delete params[:token]
                  error! 'Overload', 503
               when :login_fail
                  ptts.delete params[:token]
                  error! 'Login Failed', 401
               when :other_online
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
               error! 'Bad Request', 400 if ptt.del_other(params[:del]) == :error
               {status: 'Main Menu'}
            end

            resource :board do
               desc 'Get Boards' do
                  failure [[404, 'Connection Not Found'], [400, 'Bad Request']]
               end
               params do
                  optional :favorite, type: Boolean, default: true, desc: 'true to get favorite boards'
                  requires :token, type: String, desc: 'token which returned when connected'
               end
               get do
                  error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
                  ptt = ptts[params[:token]]
                  if params[:favorite]
                     boards = ptt.favorites
                  else
                     error! 'Not Implemented', 501
                  end
                  error! 'Bad Request', 400 if boards == :error
                  boards.each_index { |i| boards[i] = boards[i].to_hash }
                  {status: 'Main Menu', boards: boards}
               end

               route_param :name do
                  desc 'Enter a Specific Board' do
                     failure [[404, 'Connection Not Found'], [400, 'Bad Request'], [404, 'Board Not Found']]
                  end
                  params do
                     requires :name, type: String, desc: 'en_name of the board to enter'
                     requires :token, type: String, desc: 'token which returned when connected'
                  end
                  put do
                     error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
                     ptt = ptts[params[:token]]
                     name = ptt.enter! params[:name]
                     case name
                     when :error
                        error! 'Bad Request', 400
                     when :not_found
                        error! 'Board Not Found', 404
                     end
                     {status: 'In Board', name: name}
                  end
               end
            end

            resource :post do
               desc 'Get the Posts in Next Page in Current Board' do
                  failure [[404, 'Connection Not Found'], [400, 'Bad Request']]
               end
               params do
                  requires :token, type: String, desc: 'token which returned when connected'
               end
               get do
                  error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
                  ptt = ptts[params[:token]]
                  posts = ptt.list_posts
                  error! 'Bad Request', 400 if posts == :error
                  posts.each_index { |i| posts[i] = posts[i].to_hash }
                  {status: 'In Board', posts: posts}
               end

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
                  error! 'Bad Request', 400 if ptt.post!(params[:title], params[:content]) == :error
                  {status: 'In Board'}
               end

               route_param :id do
                  desc 'Return the Specific Post' do
                     detail 'nil id for read more'
                     failure [[404, 'Connection Not Found'], [404, 'Post Not Found'], [400, 'Bad Request']]
                  end
                  params do
                     requires :token, type: String, desc: 'token which returned when connected'
                     requires :id, type: String, desc: 'id of the post'
                  end
                  get do
                     error! 'Connection Not Found', 404 unless ptts.has_key? params[:token]
                     ptt = ptts[params[:token]]
                     if params[:id] == 'nil'
                        post = ptt.post
                     else
                        post = ptt.post params[:id]
                     end
                     error! 'Post Not Found', 404 if post == :not_found
                     error! 'Bad Request', 400 if post == :error
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
                        error! 'Post Not Found', 404 if status == :not_found
                        error! 'Bad Request', 400 if status == :error
                     else
                        error! 'Not Implemented', 501
                     end
                     {status: 'In Board'}
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
                     error! 'Post Not Found', 404 if ptt.push!(params[:id], params[:tag], params[:content]) == :error
                     {status: 'In Board'}
                  end
               end
            end
         end
      end

      add_swagger_documentation api_version: 'v1',
                                hide_documentation_path: true,
                                hide_format: true,
                                mount_path: '/doc',
                                base_path: "#{Settings::API_URL}/graptt/v1"
   end
end
