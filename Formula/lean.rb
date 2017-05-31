class Lean < Formula
  desc "Interactive, automatable, dependently-typed theorem prover"
  homepage "https://leanprover.github.io"
  url "https://github.com/leanprover/lean/archive/v3.0.0.tar.gz"
  sha256 "8eed2fed8158d87521552df687956f8a9b984bfae6e27f8c0fb86b885b93c851"

  bottle do
    root_url "https://dl.bintray.com/lean/lean"
    sha256 "329689bfef46678547dca02ccc637ed7cd37f6831e0577aa75dc8af0c3231345" => :yosemite
    sha256 "ac9fe7e4f2c1ea33dc6af5dada8c662728f350cad459c69cd833980a92d93fb1" => :el_capitan
  end

  option "with-boost", "Compile using boost"

  # Required
  depends_on "gmp"
  depends_on "mpfr"
  depends_on "ninja" => :build
  depends_on "cmake" => :build
  depends_on "boost" => [:build, :optional]

  def install
    args = ["-DCMAKE_INSTALL_PREFIX=#{prefix}",
            "-DCMAKE_BUILD_TYPE=Release",
            "-DTCMALLOC=OFF",
            "-GNinja",
            "-DLIBRARY_DIR=./"]
    args << "-DBOOST=ON" if build.with? "boost"
    mkdir "build" do
      system "cmake", "../src", *args
      system "ninja", "clean"
      system "ninja"
      system "ninja", "install"
    end
  end

  def caveats; <<-EOS.undent
    Lean's Emacs mode is installed into
      #{HOMEBREW_PREFIX}/share/emacs/site-lisp/lean

    To use the Lean Emacs mode, you need to put the following lines in
    your .emacs file:

      ;; Set up lean-root path
      (setq lean-rootdir "/usr/local")
      (setq-local lean-emacs-path "#{HOMEBREW_PREFIX}/share/emacs/site-lisp/lean")
      (add-to-list 'load-path (expand-file-name lean-emacs-path))
      (require 'lean-mode)
    EOS
  end

  test do
    (testpath/"succeed.lean").write <<-EOS.undent
      example (p q : Prop) : p ∧ q → q ∧ p :=
      assume Hpq : p ∧ q,
      have Hp : p, from and.elim_left Hpq,
      have Hq : q, from and.elim_right Hpq,
      show q ∧ p, from and.intro Hq Hp
    EOS

    (testpath/"fail.lean").write <<-EOS.undent
      example (p q : Prop) : p ∧ q → q ∧ p :=
      assume Hpq : p ∧ q,
      show q ∧ p, from and.intro Hpq Hpq
    EOS

    # Lean attempts to lock the library files,
    # so make a copy in the sandbox.
    mkdir_p testpath/".local/lib/lean"
    cp_r prefix/"library", testpath/".local/lib/lean/library"
    ENV["LEAN_PATH"] = testpath/".local/lib/lean/library"

    expected_failure_message = <<-EOS.undent
      /fail.lean:3:17: error: type mismatch at application
        and.intro Hpq
      term
        Hpq
      has type
        p ∧ q
      but is expected to have type
        q
    EOS
    assert_match expected_failure_message,
                 shell_output("#{bin}/lean #{testpath}/fail.lean",
                              1)

    assert_equal "", shell_output("#{bin}/lean #{testpath}/succeed.lean")
  end
end
