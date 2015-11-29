require './app/api/v1'
require './app/models/terminal'
require './app/models/board'
require './app/models/post'
require './app/models/ptt'

module Graptt
   class API < Grape::API
      mount Graptt::V1 => '/graptt/v1'
   end
end
