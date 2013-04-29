# encoding: utf-8
require 'bundler'

Bundler.require

require 'uri'

REPOSITORY_PATH = ARGV.first or raise "repository_path required"

BRANCH = ARGV[1] || 'master'

# hrforecast
def graph_post(service_name, section_name, graph_name, number, datetime)
    client = HTTPClient.new()
    puts "http://localhost:5127/api/#{URI.encode_www_form_component service_name}/#{URI.encode_www_form_component section_name}/#{URI.encode_www_form_component graph_name}"
    res = client.post("http://localhost:5127/api/#{URI.encode_www_form_component service_name}/#{URI.encode_www_form_component section_name}/#{URI.encode_www_form_component graph_name}", {
            :number => number,
            :datetime => datetime,
        })
end

def all_commits(repository, branch = 'master')
    index = 0
    max_count = 10
    commits = [true]
    while commits.any?
        commits = repository.commits(BRANCH, max_count, index)
        commits.each{ |commit|
            yield commit
        }
        index += max_count
    end
end

repository = Grit::Repo.new(REPOSITORY_PATH)
all_commits(repository, BRANCH) { |commit|
    commit.stats.to_diffstat.each{ |stat|
        next unless stat.filename =~ /^lib/
        blob = commit.tree / stat.filename
        next unless blob
        size = blob.data.split(/\n/).length
        puts [ commit.date, stat.filename, size ].join "\t"
        graph_post "loc", File.basename(REPOSITORY_PATH), stat.filename.gsub(/[\/.]/, '_'), size, commit.date
    }
}
