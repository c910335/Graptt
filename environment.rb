require 'rubygems'
require 'bundler/setup'
require 'net/telnet'
require 'securerandom'
require 'rack/cors'
require 'active_support/core_ext/string'
require 'grape'
require 'grape-swagger'
require './config/settings'
require './app/helpers/telcode'
