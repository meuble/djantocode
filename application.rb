require 'rubygems'
require 'sinatra'
require 'haml'
require 'yaml'
require "active_record"
require "awesome_print"
require 'rqrcode'
require "prawn"
require "prawn/measurement_extensions"
require 'stringio'

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

  def png_image
    RQRCode::QRCode.new("#{self.program}#{self.id}").as_png(
      :resize_gte_to => false,
      :resize_exactly_to => false,
      :fill => 'white',
      :color => 'black',
      :size => 120,
      :border_modules => 4,
      :module_px_size => 6,
      :file => nil)
  end

  def self.pdf(program_name, limit = 1)
    Prawn::Document.new(:left_margin => 3, :right_margin => 3, :top_margin => 10, :bottom_margin => 10) do
      define_grid(:columns => 5, :rows => 13, :column_gutter => 3.5.mm, :row_gutter => 0)
      font_size 9
      Code.where(:program => program_name).limit(limit).each_with_index do |code, index|
        grid(index / 5, index % 5).bounding_box do
          image StringIO.new(code.png_image.to_s), :at => [1, cursor - 2], :fit => [19.mm, 19.mm]
          draw_text code.program, :at => [18.mm, 12.mm]
          draw_text code.id, :at => [18.mm, 8.mm]
        end
      end
    end
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
  data = Code.pdf(params[:program], params[:count])

  content_type 'application/pdf'
  attachment "#{params[:program]}-#{Time.now.year}#{Time.now.month}#{Time.now.day}#{Time.now.min}#{Time.now.sec}.pdf"
  data.render
end