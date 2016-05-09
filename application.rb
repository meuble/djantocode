require 'rubygems'
require 'sinatra'
require 'haml'
require 'yaml'
require "active_record"
require "awesome_print"
require 'rqrcode'

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

  def image
    RQRCode::QRCode.new("#{self.program};#{self.id}").as_png(
      :resize_gte_to => false,
      :resize_exactly_to => false,
      :fill => 'white',
      :color => 'black',
      :size => 120,
      :border_modules => 4,
      :module_px_size => 6,
      :file => nil)
  end
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
    redirect '/codes/new'
  else
    redirect '/'
  end
end

get '/codes/new' do
  if session[:has_access]
    haml :form
  else
    redirect '/'
  end
end

post '/codes' do
  count = (params[:count].to_s.to_i || 1)
  codes = (0...count).to_a.map { Code.new(:program => params[:program]) }
  ap codes
  if codes.inject(true) {|a, c| a && c.save }
    redirect "/codes/thanks/#{params[:program]}/#{count}"
  else
    redirect "/codes/new"
  end
end

get '/codes/thanks/:program/:count' do
  haml :thanks
end

get '/codes/download/:program/:count' do
  @code = Code.where(:program => params[:program]).last
  image = @code.image

  content_type 'application/png'
  attachment "#{@code.program}-#{Time.now.year}#{Time.now.month}#{Time.now.day}#{Time.now.min}#{Time.now.sec}.png"
  image.to_s
end