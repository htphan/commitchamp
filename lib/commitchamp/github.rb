require 'httparty'
require 'io/console'
require 'pry'

module Commitchamp
  class Github
    include HTTParty
    base_uri "https://api.github.com"

    def initialize
      access_token = ENV['OAUTH_TOKEN']
      if access_token == nil
        puts "What is your access token?"
        access_token = STDIN.noecho(&:gets).chomp
      end
      @headers = { "Authorization" => "token #{access_token}",
                "User-Agent" => "HTTParty" }
    end

    def get_user(username)
      self.class.get("/users/#{username}", headers: @headers)
    end

    def get_single_repo(org_name, repo_name)
      self.class.get("/repos/#{org_name}/#{repo_name}", headers: @headers)
    end

    def get_repos(org_name)
      self.class.get("/orgs/#{org_name}/repos?per_page=100", headers: @headers)

      # "owner" -> "type" => "Organization"
    end

    def contributions_page(org, repo_name, page=1)
      # params = { page: page }
      # options = {
      #   headers: @headers,
      #   query: params
      # }
      self.class.get("/repos/#{org}/#{repo_name}/stats/contributors?page=#{page}&per_page=100", 
                      headers: @headers)
    end

    # def get_contributions(org, repo_name)
    #   total_contributors = []
    #   page = 1
    #   contributions = self.contributions_page(org, repo_name, page).to_a
    #   total_contributors.concat(contributions)
    #   while contributions.length == 100
    #       page += 1
    #       contributions = self.contributions_page(org, repo_name, page).to_a
    #       total_contributors.concat(contributions)
    #       puts 'split'
    #   end
    #   total_contributors
    # end
  end
end
