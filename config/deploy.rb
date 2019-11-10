lock '~> 3.11.0'

set :application, 'virtuatable-uploads'
set :deploy_to, '/var/www/uploads'
set :repo_url, 'git@github.com:jdr-tools/uploads.git'
set :branch, 'master'

append :linked_files, 'config/mongoid.yml'
append :linked_files, 'config/buckets.yml'
append :linked_files, '.env'
append :linked_dirs, 'bundle'
append :linked_dirs, 'log'