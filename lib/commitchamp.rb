$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'pry'

require 'commitchamp/version'
require 'commitchamp/init_db'
require 'commitchamp/github'
require 'commitchamp/user'
require 'commitchamp/repo'
require 'commitchamp/contribution'


module Commitchamp
  class App
    def initialize
      @github = Github.new
    end

    def create_user(username)
      if Commitchamp::User.find_by(login: username) == nil
        user = @github.get_user(username)
        Commitchamp::User.find_or_create_by(login: user['login'])
      end
      Commitchamp::User.find_by(login: username)
    end

    def create_repo(org, repo_name)
      if Commitchamp::Repo.find_by(name: repo_name, organization: org) == nil
        repo = @github.get_single_repo(org, repo_name)
        Commitchamp::Repo.find_or_create_by(name: repo['name']) do |r|
          r.organization = repo['organization']['login']
          r.full_name = repo['full_name']
        end
      end
      Commitchamp::Repo.find_by(name: repo_name, organization: org)
    end

    def add_contributions(contribution_array)
      a = []
      d = []
      c = []
      contribution_array['weeks'].each do |h|
        a << h['a']
        d << h['d']
        c << h['c']
      end
      commit = c.reduce(:+)
      add = a.reduce(:+)
      delete = d.reduce(:+)
      contributions = {
        additions: add,
        deletions: delete,
        commits: commit,
      }
    end

    def create_contribution(contribution_array, org, repo_name)
      user = create_user(contribution_array['author']['login'])
      repo = create_repo(org, repo_name)
      contributions = add_contributions(contribution_array)
      Commitchamp::Contribution.find_or_create_by(user_id: user.id, repo_id: repo.id) do |c|
        c.additions = contributions[:additions]
        c.deletions = contributions[:deletions]
        c.commits = contributions[:commits]
      end
    end

    def split_contributions(org, repo)
      total_contributors = []
      page = 1
      contributions = @github.contributions_page(org, repo).to_a
      total_contributors.concat(contributions)
      total_contributors
    end

    def bulk_contributions(org, repo)
      total_contributors = split_contributions(org, repo)
      total_contributors.each do |x|
        self.create_contribution(x, org, repo)
      end
    end

    def prompt(message, validator)
      puts message
      input = gets.chomp
      until input =~ validator
        puts "I'm sorry, your input was not recognized."
        puts message
        input = gets.chomp
      end
      input 
    end

    def choose_repo
      input = prompt("Would you like to access an existing repo or fetch a new one? (e/n)", 
                      /^[en]$/)
      if input == 'n'
        org = prompt("What is the name of the organization?", /^.+$/)
        repo = prompt("What is the name of the repository?", /^.+$/)
        puts "Please wait while we retrieve data..."
        self.bulk_contributions(org, repo)
        repo = Commitchamp::Repo.find_by(name: repo)
        repo.full_name
      else
        puts "\nExisting Repositories:"
        puts "(organization/repository)"
        repos = Commitchamp::Repo.all.to_a
        repos.each do |r|
          puts "#{r['full_name']}"
        end
        choice = prompt("\nWhich repository would you like to access?", /^.+$/)
        return choice
      end
    end

    def display_contributions(repo_full_name)
      repo = Commitchamp::Repo.find_by(full_name: repo_full_name)
      contributors = repo.contributions.order('additions + deletions + commits DESC').limit(10)
      puts "\n##Contributions for '#{repo.full_name}'"
      puts "\nUsername | Additions | Deletions | Commits"
      contributors.each do |x|
        puts "#{x.user.login} | #{x.additions} | #{x.deletions} | #{x.commits}"
      end
      puts
    end

    def run
      input = prompt("Would you like to view contribution statistics on a repository? (y/n)", 
                        /^[yn]$/)
      until input == "n"
        repo_full_name = self.choose_repo
        self.display_contributions(repo_full_name)
        input = prompt("Would you like to view contribution statistics on a repository? (y/n)", 
                        /^[yn]$/)
      end
      puts "Thank you!"
    end
  end
end

app = Commitchamp::App.new
app.run

# binding.pry
