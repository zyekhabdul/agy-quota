class AgyQuota < Formula
  desc "Antigravity Multi-Account Token, Quota & Tier Bulk Checker"
  homepage "https://github.com/zyekhabdul/agy-quota"
  url "https://github.com/zyekhabdul/agy-quota/archive/refs/tags/v1.2.0.tar.gz"
  license "MIT"
  head "https://github.com/zyekhabdul/agy-quota.git", branch: "main"

  depends_on "python@3.12"

  def install
    bin.install "bin/agy-quota"
    bin.install_symlink "agy-quota" => "agy-tokens"
  end

  test do
    system bin/"agy-quota", "--help"
    system bin/"agy-tokens", "--help"
  end
end
