# GIT_SHA is set on the DigitalOcean web service as ${web.COMMIT_HASH}, a runtime-only bindable variable.
class DeployedRevision
  def self.current
    sha = ENV["GIT_SHA"].presence || local_sha
    new(sha) if sha
  end

  def self.local_sha
    return unless Rails.env.development?

    IO.popen(%w[git rev-parse HEAD], err: File::NULL, &:read).strip.presence
  rescue Errno::ENOENT
    nil
  end
  private_class_method :local_sha

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
