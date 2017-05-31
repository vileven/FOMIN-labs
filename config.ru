ENV['NLS_LANG'] = 'RUSSIAN_RUSSIA.AL32UTF8'

require_relative 'app'
require 'sinatra'
require 'rubygems'

require File.expand_path '../app.rb', __FILE__

set :public_folder, File.dirname(__FILE__) + '/public'
set :static, true
set :static_cache_control, [:public, max_age: 0]

run Application
