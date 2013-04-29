require 'bundler'

Bundler.require

REPOSITORY_PATH = ARGV.first or raise "repository_path required"

BRANCH = ARGV[1] || 'master'

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
    }
}
