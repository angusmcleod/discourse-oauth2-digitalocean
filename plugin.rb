# name: discourse-oauth2-digitalocean
# about: Digital Ocean Discourse Plugin
# version: 0.1
# authors: Angus McLeod
# url: https://github.com/angusmcleod/discourse-oauth2-digitalocean

after_initialize do
  load File.expand_path("../jobs/scheduled/deactivate_unauthorised_users.rb", __FILE__)
end
