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

passwords = JSON.parse(config["password"] || ENV["WEBSITE_PASSWORD"])

class Code < ActiveRecord::Base
  validates_presence_of :program

  def png_image
    RQRCode::QRCode.new("#{self.program}#{self.code}").as_png(
      :resize_gte_to => false,
      :resize_exactly_to => false,
      :fill => 'white',
      :color => 'black',
      :size => 120,
      :border_modules => 4,
      :module_px_size => 6,
      :file => nil)
  end

  def self.pdf(program_name, start = 0)
    Prawn::Document.new(:left_margin => 3, :right_margin => 3, :top_margin => 10, :bottom_margin => 10) do
      define_grid(:columns => 5, :rows => 13, :column_gutter => 3.5.mm, :row_gutter => 2)
      font_size 9
      Code.where(:program => program_name).where("code >= ?", start.to_s.rjust(6, "0")).limit(start + 65).each_with_index do |code, index|
        grid(index / 5, index % 5).bounding_box do
          image StringIO.new(code.png_image.to_s), :at => [1, cursor - 2], :fit => [19.mm, 19.mm]
          draw_text code.program, :at => [18.mm, 10.mm]
          draw_text code.code, :at => [18.mm, 6.mm]
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
  if passwords.keys.include?(params[:password])
    session[:has_access] = true
    session[:program] = passwords[params[:password]]
    redirect '/codes/choices'
  else
    redirect '/'
  end
end

get '/codes/choices' do
  if session[:has_access]
    haml :choices
  else
    redirect '/'
  end
end

post '/codes/choices' do
  if session[:has_access]
    if params[:choice][:action] == "new"
      redirect '/codes/new'
    else
      redirect '/codes/edit'
    end
  else
    redirect '/'
  end
end

get '/codes/new' do
  if session[:has_access]
    last_code = Code.order(:code).last
    @last_key = last_code ? last_code.code : 0
    haml :new_form
  else
    redirect '/'
  end
end

get '/codes/edit' do
  if session[:has_access]
    last_code = Code.order(:code).last
    @last_key = last_code ? last_code.code : 0
    haml :edit_form
  else
    redirect '/'
  end
end

post '/codes' do
  count = 65
  last_code = Code.order(:code).last
  last_key = last_code ? last_code.code : 0
  codes = (1...count + 1).to_a.inject([]) {|acc, i| acc << Code.new(:program => session[:program], :code => ((last_key || 0).to_i + i).to_s.rjust(6, "0")); acc }

  if codes.inject(true) {|a, c| a && c.save }
    redirect "/codes/thanks/#{last_key}"
  else
    redirect "/codes/new"
  end
end

get '/codes/update' do
  last_code = Code.order(:code).last
  if params[:start_id].to_i > (last_code ? last_code.code : 0).to_i
    redirect '/codes/edit?error=true'
  else
    start = ((params[:start_id].to_i || 0) / 65) * 65
    redirect "/codes/thanks/#{start}"
  end
end

get '/codes/thanks/:count' do
  haml :thanks
end

get '/codes/download/:program/:start' do
  data = Code.pdf(session[:program], params[:start].to_i)

  content_type 'application/pdf'
  attachment "#{session[:program]}-#{Time.now.year}#{Time.now.month}#{Time.now.day}#{Time.now.min}#{Time.now.sec}.pdf"
  data.render
end