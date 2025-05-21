# Add your own tasks in files placed in lib/tasks ending in .rake,
require File.expand_path('../config/application', __FILE__)

Rails.application.load_tasks

desc "Build local docker image"
task "build:docker" do |t, args|
    sh "docker build --no-cache -t awbw-portal ."
end