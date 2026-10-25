# GIT_SHA is set on the DigitalOcean web service as ${web.COMMIT_HASH}, a runtime-only bindable variable.
class DeployedRevision
  def self.current
    sha = ENV["GIT_SHA"].presence
    new(sha) if sha
  end

  def initialize(sha)
    @sha = sha
  end

  def short_sha
    @sha.first(7)
  end

  def compare_url
    "https://github.com/#{FeatureDecorator::GITHUB_REPO}/compare/#{@sha}...main"
  end
end
