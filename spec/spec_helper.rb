require 'spec_helper'
require 'airborne'
require './environment'
require './app'
require './spec/data'

RSpec.configure do |config|
   config.color = true
   config.formatter = :documentation
   config.mock_with :rspec
   config.raise_errors_for_deprecations!
end

Airborne.configure do |config|
   config.rack_app = Graptt::API
end

describe Terminal do
   context 'when load PTT start page' do
      let(:terminal) {Terminal.new}
      it 'should convert to readable page' do
         terminal.print TestData::START_PAGE_ANSI
         expect(terminal.to_s).to eq TestData::START_PAGE
      end
   end
end

describe Graptt::API do

   base_url = '/graptt/v1'

   context 'POST /connection' do
      it 'should connect to PTT' do
         post base_url + '/connection'
         expect_status 201
         expect_json 'status', 'Connected'
         expect_json_types status: :string, token: :string
         $token = json_body[:token]
      end
   end

   describe 'when connected' do

      before { skip 'Not Connected' if $token.nil? }

      context 'PUT /login' do
         it 'should login PTT' do
            put base_url + '/login', {account: TestData::ACCOUNT, password: TestData::PASSWORD, token: $token}
            expect_status 200
            expect_json status: regex('^(Other Online|Main Menu)$')
            $status = json_body[:status]
         end
      end

      describe 'when logged in' do

         before { skip 'Not Logged in' if $status.nil? }

         context 'DELETE /other' do
            it 'should delete other online' do
               skip 'No Other Online' unless $status == 'Other Online'
               delete base_url + '/other', {token: $token}
               expect_status 200
               expect_json status: 'Main Menu'
            end
         end

         context 'GET /boards' do
            it 'should get favorite boards' do
               get base_url + '/boards?token=' + $token
               expect_status 200
               expect_json 'status', 'Main Menu'
               expect_json_types 'boards', :array
               $boards = json_body[:boards]
               $boards.each do |board|
                  expect(board.keys).to contain_exactly(:num, :en_name, :zh_name, :popularity, :type, :unread)
               end
            end
         end

         context 'PUT /board' do
            it 'should enter a board' do
               skip 'No Boards Get' if $boards.nil?
               board_name = $boards.sample[:en_name]
               put base_url + '/board', {token: $token, name: board_name}
               expect_status 200
               expect_json status: 'In Board', name: board_name
               $status = json_body[:status]
            end
         end

         describe 'when entered a board' do

            before { skip 'Not in Board' unless $status == 'In Board' }

            context 'GET /posts' do
               it 'should list posts' do
                  $posts = []
                  5.times do
                     get base_url + '/posts?token=' + $token
                     expect_status 200
                     expect_json 'status', 'In Board'
                     expect_json_types 'posts', :array
                     $new_posts = json_body[:posts]
                     $new_posts.each do |post|
                        expect(post.keys).to include(:num, :author, :title, :date, :status, :like, :source)
                     end
                     $posts += $new_posts.delete_if { |post| post[:id].nil? }
                  end
               end
            end

            context 'GET /post' do
               it 'should get a post with content' do
                  skip 'No Posts Get' if $posts.nil?
                  get base_url + '/post?token=' + $token + '&id=' + URI.escape($posts.sample[:id])
                  first = true
                  begin
                     get base_url + '/post?token=' + $token unless first
                     first = false
                     puts body
                     expect_status 200
                     expect_json 'status', 'In Post'
                     expect_json_types post: {author: :string, end: :boolean, title: :string, id: :string, url: :string, pttcoin: :integer, content: :array}
                  end until json_body[:post][:end]
               end
            end

            context 'PUT /post' do
               it 'should set a post read' do
                  skip 'No Posts Get' if $posts.nil?
                  put base_url + '/post', {token: $token, id: $posts.sample[:id]}
                  puts body
                  expect_status 200
                  expect_json status: 'In Board'
               end
            end

         end

         describe 'when created something' do

            before :all do
               skip 'Prevent Shitpost'
               put base_url + '/board', {token: $token, name: 'Test'}
               skip 'Can\'t Enter Test' unless response.code == 200
            end

            context 'POST /post' do
               it 'should create a new post in Test' do
                  post base_url + '/post', {token: $token, title: TestData::POST_TITLE, content: TestData::POST_CONTENT}
                  expect_status 201
                  expect_json status: 'In Board'
               end
            end

            context 'POST /push' do
               it 'should push the latest post in Test' do
                  get base_url + '/posts?token=' + $token
                  skip 'Can\'t Get Posts' if response.status != 200
                  posts = json_body[:posts]
                  while posts.first[:num] == 0 || ! posts.first.has_key?(:id)
                     posts.shift
                  end
                  puts posts.first
                  post base_url + '/push', {token: $token, id: posts.first[:id], tag: TestData::PUSH_TAG, content: TestData::PUSH_CONTENT}
                  expect_status 201
                  expect_json status: 'In Board'
               end
            end

         end

      end

      context 'DELETE /connection' do
         it 'should disconnect from PTT' do
            delete base_url + '/connection', {token: $token}
            expect_status 200
            expect_json status: 'Bye Bye'
         end
      end

   end
end
