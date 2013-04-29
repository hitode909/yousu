require 'bundler'

Bundler.require

REPOSITORY_PATH = ARGV.first or raise "repository_path required"

BRANCH = ARGV[1] || 'master'

class Yousu
    def self.each_commits(repository, branch = 'master', index = 0, &block)
        max_count = 10
        commits = repository.commits(BRANCH, max_count, index)
        return unless commits.length > 0
        commits.each{ |commit|
            yield commit
        }
        each_commits(repository, branch, index + max_count, &block)
    end
end

repository = Grit::Repo.new(REPOSITORY_PATH)
Yousu.each_commits(repository, BRANCH) { |commit|
    commit.stats.to_diffstat.each{ |stat|
        next unless stat.filename =~ /^lib/
        blob = commit.tree / stat.filename
        next unless blob
        size = blob.data.split(/\n/).length
        puts [ commit.date, stat.filename, size ].join "\t"
    }
}
