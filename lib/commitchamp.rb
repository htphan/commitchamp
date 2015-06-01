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

    # Creates a single user
    def create_user(username)
      if Commitchamp::User.find_by(login: username) == nil
        user = @github.get_user(username)
        Commitchamp::User.find_or_create_by(login: user['login'])
      end
      Commitchamp::User.find_by(login: username)
    end

    # Creates a single repo
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

    # Takes an array of contributions and adds additions, deletions, and commits
    # Returns an array of those sums
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

    # Creates a single contribution
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

    # Used to retrieve contributions of a repo and split if on multiple pages
    def split_contributions(org, repo)
      total_contributors = []
      page = 1
      contributions = @github.contributions_page(org, repo).to_a
      total_contributors.concat(contributions)
      total_contributors
    end

    # Takes an organization and repository name:
    # Retrieves all contributions of a repo and bulk creates contributions in database
    def bulk_contributions(org, repo)
      total_contributors = split_contributions(org, repo)
      total_contributors.each do |x|
        self.create_contribution(x, org, repo)
      end
    end

    # Takes an organization name:
    # Bulk creates repos and contributions of each repo for the specified organization
    def bulk_org_contributions(org)
      repos = @github.get_repos(org)
      repos.each do |r|
        self.bulk_contributions(org, r['name'])
      end
    end

    # Displays the repositories of a specified organization
    def display_org_repos(org)
      repos = Commitchamp::Repo.where(organization: org).order(name: :asc)
      puts "\n## Repositories for Organization: #{org}"
      repos.each do |r|
        puts "#{r.name}"
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

    # First: Prints all organizations in the database, and allows selection
    # Second: Prints all repos in the specified organization, and allows selection
    def print_existing_repos
      puts "\n### Existing Organizations ###"
      orgs = Commitchamp::Repo.select(:organization).distinct.order(organization: :asc)
      orgs.each do |o|
        puts "#{o.organization}"
      end
      input = prompt("\nWhich organization would you like to access?", /^.+$/)
      puts
      self.display_org_repos(input)
    end

    # Allows user interaction to specify control flow
    def choose_repo
      input = prompt("What would you like to do?"\
                     "\n1: Access Existing Repo \n2: Access a new Repo"\
                     "\n3: I want all the Repos!",
                      /^[123]$/)
      if input == '2'
        org = prompt("What is the name of the organization?", /^.+$/)
        repo = prompt("What is the name of the repository?", /^.+$/)
        puts "Please wait while we retrieve data..."
        self.bulk_contributions(org, repo)
        repo = Commitchamp::Repo.find_by(name: repo)
        repo.full_name
      elsif input == "1"
        self.print_existing_repos
        choice = prompt("\nWhich repository would you like to access?", /^.+$/)
        choice = Commitchamp::Repo.find_by(name: choice).full_name
        return choice
      else
        text =  "Wow... Greedy much? Fine..."\
                "\nWhat is the name of the organization that you"\
                "\n  would like to import all its repos?"
        org = prompt(text, /^.+$/)
        puts "Hold your horses... This is going to take a minute..."
        self.bulk_org_contributions(org)
        self.display_org_repos(org)
        choice = prompt("\nWhich repo would you like to access?", /^.+$/)
        choice = Commitchamp::Repo.find_by(name: choice).full_name
        return choice
      end
    end

    # Displays the top 10 contributions of a specified repository
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

    # Initial run of the program
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
