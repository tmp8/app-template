# tmp8-apptemplate for the plat_forms challenge 2011

def ask_with_validation(question)
  answer = ask(question)
  while !(yield(answer))
    answer = ask(question)
  end
  answer
end

# <<<----------| rvm |----------->>>
rvm_lib_path = "#{`echo $rvm_path`.strip}/lib"
$LOAD_PATH.unshift(rvm_lib_path) unless $LOAD_PATH.include?(rvm_lib_path)
require 'rvm'
env = RVM::Environment.new("1.9.2")
env.gemset_create(app_name)
env.gemset_use!(app_name)
run 'gem install bundler'

file '.rvmrc', "rvm use 1.9.2@#{@app_name}"

# <<<----------| misc |----------->>>

run 'echo TODO > README'

git :init

inside 'config' do
  run "cp database.yml database.yml.example"
  run 'rm database.yml'
end

run "rm public/index.html"
gem "capistrano"

# <<<---------| testing |-------->>>
#
gem "capybara", :group => "test"
gem "launchy", :group => "test"
gem "shoulda", :group => "test"
gem "rr", :group => "test"
gem "factory_girl", :group => "test"
gem "faker", '0.3.1', :group => "test"
gem "tmp8-snailgun", :group => "test"
gem "timecop", :group => "test"
gem "webmock", :group => "test"
gem "fixture_background", '0.9.1', :group => "test"
gem "simplecov", :require => false , :group => "test"
gem "simplecov-rcov", :require => false, :group => "test"
 

  file '.snailgun.ignore', <<-END
test_helper
rails/test_help
END

inside "test" do
  file "intergration_test_helper.rb", <<-END
require "test_helper"
require "capybara/rails"

Capybara.default_selector = :css

module ActionController
  class IntegrationTest
    include Capybara
  end
end
END
  
  run "rm test_helper.rb"
  file "test_helper.rb", <<-END

if ENV['COVERAGE']
  require 'simplecov'
  require 'merged_formatter'
  SimpleCov.formatter = SimpleCov::Formatter::MergedFormatter
  SimpleCov.start 'rails'
end

ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'webmock/test_unit'
require 'factories'


class ActiveSupport::TestCase
  include ::FixtureBackground::ActiveSupport::TestCase

  include RR::Adapters::TestUnit
  
  # Add more helper methods to be used by all tests here...
  
end
END
end

  file "lib/merged_formatter.rb", <<-END
require 'simplecov-rcov'
class SimpleCov::Formatter::MergedFormatter
  def format(result)
     SimpleCov::Formatter::HTMLFormatter.new.format(result)
     SimpleCov::Formatter::RcovFormatter.new.format(result)
  end
end
END

  file "ci.sh", <<-END
#!/bin/bash -l
vncserver :1 -geometry 1280x1024 -depth 24 -alwaysshared
export DISPLAY=:1
export COVERAGE=true
rvm use 1.9.2@#{@app_name} --create
ruby /var/lib/hudson/create_database_config.rb
bundle install
bundle check
rake db:drop:all
rake db:create:all
rake db:migrate
rake db:test:prepare
rake
END
# <<<---------| db |---------->>>

gsub_file "Gemfile", "gem 'sqlite3-ruby', :require => 'sqlite3'", ""

gem "mysql2"
file 'config/database.yml', <<-END
login: &login
  adapter: mysql2
  username: root
  password: 
  host: 127.0.0.1

development:
  <<: *login
  database: #{@app_name}_development

test:
  <<: *login
  database: #{@app_name}_test
END

# <<<---------| haml |---------->>>

gem 'haml'
gem 'haml-rails'

inside 'app/views/layouts' do
  run 'rm application.html.erb'
  file 'application.html.haml', <<-END
!!! 5
%head
 %title #{@app_name.camelcase}
 = stylesheet_link_tag :all
 = stylesheet_link_tag 'screen.css', :media => 'screen, projection'
 = stylesheet_link_tag 'print.css', :media => 'print'
 /[if IE]
  = stylesheet_link_tag 'ie.css', :media => 'screen, projection'
 
 = javascript_include_tag :defaults
 = csrf_meta_tag
 = yield(:head)

%body

=yield
  END
end

# <<<---------| compass gem |-------->>>

gem 'compass'

# <<<---------| jQuery |-------->>>
inside "public/javascripts" do
  get "https://github.com/rails/jquery-ujs/raw/master/src/rails.js", "rails.js"
  get "http://code.jquery.com/jquery-1.4.4.js", "jquery/jquery.js"
end

application do
  "\n    config.action_view.javascript_expansions[:defaults] = %w(jquery.min rails)\n"
end

gsub_file "config/application.rb", /# JavaScript.*\n/, ""
gsub_file "config/application.rb", /# config\.action_view\.javascript.*\n/, ""

# <<<----------| hoptoad-notifier |--------->>>

gem "hoptoad_notifier", "~> 2.3"

# <<<----------| devise |------->>>

gem "devise"

# <<<---------| bundler |------->>>
run "bundle install"

# hoptoad

hoptoad_api_key = ask_with_validation("Please enter your hoptoad api key.") { |api_key|
  api_key =~ /[a-z0-9]{32}/
}
run "rails generate hoptoad #{ hoptoad_api_key }"

# devise

generate "devise:install"
generate "devise User"

# <<<---------| compass initalize |--------->>>

run 'compass init rails . --sass-dir "app/stylesheets" --css-dir "public/stylesheets"'


# <<<---------| capistrano |-------------->>>

 capify!

 run "rm config/deploy.rb"
 file "config/deploy.rb", <<-END
$:.unshift(File.expand_path('./lib', ENV['rvm_path'])) # Add RVM's lib directory to the load path.
require "rvm/capistrano"                  # Load RVM's capistrano plugin.
set :rvm_ruby_string, '1.9.2@server_test'        # Or whatever env you want it to run in.

ssh_options[:forward_agent] = true

set :user, '<insert username here>'
set :domain, '<insert domain here>'
set :application, '#{@app_name}'

# file paths
set :repository,  "\#{user}@\#{domain}:~/repos/\#{application}/.git" 
set :deploy_to, "/home/#\{user}/\#{application}" 

# distribute your applications across servers (the instructions below put them
# all on the same server, defined above as 'domain', adjust as necessary)
role :app, domain
role :web, domain
role :db, domain, :primary => true


# miscellaneous options
set :deploy_via, :remote_cache
set :scm, 'git'
set :branch, 'master'
set :scm_verbose, true
set :use_sudo, false

namespace :deploy do

  desc "cause Passenger to initiate a restart"
  task :restart do
    run "touch \#{current_path}/tmp/restart.txt" 
  end

  desc "reload the database with seed data"

  task :seed do
    run "cd \#{current_path}; rake db:seed RAILS_ENV=production"
  end

end

after "deploy:update_code", :bundle_install, :symlink_config
desc "install the necessary prerequisites"
task :bundle_install, :roles => :app do
  run "cd \#{release_path} && bundle install"
end

task :symlink_config do
  run "ln -s \#{shared_path}/config/database.yml \#{release_path}/config/database.yml"
end
 
END
# <<<---------| git |-------->>>

run 'rm .gitignore'
file ".gitignore", <<-END
.DS_Store
log/*.log
tmp/**/*
config/database.yml
db/*.sqlite3
END

git :add => '.', :commit => '-m "initial commit"'

puts "\n " + ("*" * 20)

if yes?("create a new github repository for this project?")
  remote = true
  login = ask_with_validation("please insert your github user name:") { |answer| answer =~ /\w*/ }
  token = ask_with_validation("please insert your github api-token:") { |answer| answer =~ /[a-z0-9]{32}/}

  run "curl -F 'login=#{login}' -F 'token=#{token}' https://github.com/api/v2/yaml/repos/create -F 'name=#{@app_name}'"

  run "git remote add origin git@github.com:#{login}/#{@app_name}.git" 
end

run "git flow init"
run "git push origin develop" if remote

