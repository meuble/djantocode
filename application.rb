require 'rubygems'
require 'sinatra'
require 'haml'
require 'yaml'
require "active_record"

enable :sessions
set :haml, :format => :html5

database_config_file = File.join(File.dirname(File.expand_path(__FILE__)), 'config', 'database.yml')
config_file = File.join(File.dirname(File.expand_path(__FILE__)), 'config', 'config.yml')

config = File.exists?(config_file) ? YAML::load_file(config_file) : {}
database_config = File.exists?(database_config_file) ? YAML::load(File.read(database_config_file))["production"] : config["database"]
ActiveRecord::Base.establish_connection(database_config)

password = config["password"] || ENV["WEBSITE_PASSWORD"]

class Code < ActiveRecord::Base
  validates_presence_of :program
end

get '/' do
  haml :index
end

get '/reset_session' do
  session[:has_access] = nil
end

post '/gate' do
  if password == params[:password]
    session[:has_access] = true
    redirect '/code/new'
  else
    redirect '/'
  end
end