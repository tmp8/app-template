
def ask_with_validation(question)
  answer = ask(question)
  while !(yield(answer))
    answer = ask(question)
  end
  answer
end
# <<<----------| misc |----------->>>
rvm_lib_path = "#{`echo $rvm_path`.strip}/lib"
$LOAD_PATH.unshift(rvm_lib_path) unless $LOAD_PATH.include?(rvm_lib_path)
require 'rvm'
env = RVM::Environment.new("1.9.2")
env.gemset_create(app_name)
env.gemset_use!(app_name)
run 'gem install bundler'

run 'echo TODO > README'

git :init

inside 'config' do
  run "cp database.yml database.yml.example"
  run 'rm database.yml'
end


# <<<----------| rvm |----------->>>

file '.rvmrc', "rvm use 1.9.2@#{@app_name}"

# <<<---------| testing |-------->>>
gem 'shoulda', :group => :test
gem 'factory_girl', :group => :test
gem 'fixture_background', :group => :test
gem 'tmp8-snailgun', :group => :test
gem 'timecop', :group => :test

file '.snailgun.ignore', <<-END
test_helper
rails/test_help
END

# <<<---------| db |---------->>>

gem 'mysql2'
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

# <<<---------| bundler |------->>>

run "bundle install"

# <<<---------| compass initalize |--------->>>

run 'compass init rails . --sass-dir "app/stylesheets" --css-dir "public/stylesheets"'

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

