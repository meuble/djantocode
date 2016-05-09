require 'rubygems'
require 'yaml'
require "active_record"
require "awesome_print"


database_config_file = File.join(File.dirname(File.expand_path(__FILE__)), '..', 'config', 'database.yml')
config_file = File.join(File.dirname(File.expand_path(__FILE__)), '..', 'config', 'config.yml')


config = File.exists?(config_file) ? YAML::load_file(config_file) : {}
database_config = File.exists?(database_config_file) ? YAML::load(File.read(database_config_file))["production"] : config["database"]
ActiveRecord::Base.establish_connection(database_config)

ActiveRecord::Schema.define(:version => 201605092229) do
  create_table "codes", :force => true do |t|
    t.string "program"
    t.datetime "created_at"
    t.datetime "updated_at"
  end
end
