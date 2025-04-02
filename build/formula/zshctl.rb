require "formula"

class Zshctl < Formula
  desc "Zsh CLI application framework."
  homepage "https://github.com/flatheadmill/zshctl"
  url "https://zshctl.sh/downloads/zshctl-VERSION.tar.gz", :using => :curl
  sha256 "SHA256SUM"

  def install
    bin.install "zshctl"
  end

  # Homebrew requires tests.
  test do
    assert_match "VERSION", shell_output("#{bin}/zshctl version", 2)
  end
end
