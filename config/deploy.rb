# config valid only for current version of Capistrano
lock '3.4.1'

set :application, 'awbw'
set :repo_url, 'git@github.com:awindowbetweenworlds/awbw-dashboard.git'
set :branch, 'master'

set :deploy_to, '/home/devteam/public_html/awbw/'

SSHKit.config.command_map[:rake]  = "bundle exec rake"
SSHKit.config.command_map[:rails] = "bundle exec rails"

namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end
end

set :linked_dirs, %w{public/system}


