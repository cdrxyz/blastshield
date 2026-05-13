class Blastshield < Formula
  desc "Sandbox AI coding agents with kernel-level protection against destructive cloud CLI commands"
  homepage "https://cdrxyz.github.io/blastshield"
  url "https://github.com/cdrxyz/blastshield/archive/refs/tags/v#{version}.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "Apache-2.0"

  version "0.1.0"  # Updated automatically by release workflow

  depends_on "bash"

  def install
    bin.install "blastshield"
    bin.install "helpers/blastshield-guard"
    bash_completion.install "completions/blastshield.bash"
    bash_completion.install "completions/blastshield-guard.bash"
  end

  test do
    output = shell_output("#{bin}/blastshield --version 2>/dev/null || #{bin}/blastshield --version")
    assert_match "blastshield v#{version}", output
  end
end
