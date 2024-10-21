(define-module (btv rust)
  #:use-module (gnu packages rust)
  #:use-module (guix packages)
  #:use-module (gnu packages)
  #:use-module (srfi srfi-1)
  #:use-module (gnu packages llvm-meta)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages web)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages gdb)
  #:use-module (gnu packages linux)
  #:use-module (guix utils)
  #:use-module (guix platform)
  #:use-module (guix build-system trivial)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:))

(define rust-bootstrapped-package (@@ (gnu packages rust) rust-bootstrapped-package))
(define %cargo-reference-hash (@@ (gnu packages rust) %cargo-reference-hash))

(define-public libclang-definer
  (package
    (name "libclang-definer")
    (propagated-inputs `(,clang))
    (native-search-paths
     `(,(search-path-specification
         (variable "LIBCLANG_PATH")
         (files '("lib" "lib64")))))
    (build-system trivial-build-system)
    (version "1")
    (source #f)
    (synopsis "define LIBCLANG_PATH as the path to libclang.so")
    (description "define LIBCLANG_PATH as the path to libclang.so")
    (license license:public-domain)
    (home-page #f)
    (arguments
     `(#:modules ((guix build utils))
       #:target #f
       #:builder ,#~(begin
                      (use-modules (guix build utils))
                      (mkdir-p #$output))))))

(define-public rust-1.78
  (let ((base-rust (rust-bootstrapped-package rust-1.77 "1.78.0"
                                              "1afmj5g3bz7439w4i8zjhd68zvh0gqg7ymr8h5rz49ybllilhm7z")))
    (package
      (inherit base-rust)
      (source
       (origin
         (inherit (package-source base-rust))
         ;; see https://github.com/rust-lang/rust/pull/125844
         (patches (search-patches "rustc-unwinding-fix.patch")))))))

(define-public rust-1.79
  (let ((base-rust (rust-bootstrapped-package rust-1.78 "1.79.0"
                    "1h282jb1yxc69999w4nhvqb08rw2jy32i9njdjqrz78zglycybhp")))
    (package
      (inherit base-rust)
      (source
       (origin
         (inherit (package-source base-rust))
         (snippet
          '(begin
             (for-each delete-file-recursively
                       '("src/llvm-project"
                         "vendor/jemalloc-sys-0.5.4+5.3.0-patched/jemalloc"
                         "vendor/openssl-src-111.28.1+1.1.1w/openssl"
                         "vendor/tikv-jemalloc-sys-0.5.4+5.3.0-patched/jemalloc"))
             ;; Remove vendored dynamically linked libraries.
             ;; find . -not -type d -executable -exec file {} \+ | grep ELF
             ;; Also remove the bundled (mostly Windows) libraries.
             (for-each delete-file
                       (find-files "vendor" "\\.(a|dll|exe|lib)$"))
             ;; Adjust vendored dependency to explicitly use rustix with libc backend.
             (substitute* '("vendor/tempfile-3.7.1/Cargo.toml"
                            "vendor/tempfile-3.10.1/Cargo.toml")
               (("features = \\[\"fs\"" all)
                (string-append all ", \"use-libc\""))))))))))

(define-public rust-1.80
  (let ((base-rust (rust-bootstrapped-package rust-1.79 "1.80.1"
                                              "1i1dbpwnv6ak244lapsxvd26w6sbas9g4l6crc8bip2275j8y2rc")))
    (package
      (inherit base-rust)
      (source
       (origin
         (inherit (package-source base-rust))
         (snippet
          '(begin
             (for-each delete-file-recursively
                       '("src/llvm-project"
                         "vendor/jemalloc-sys-0.5.3+5.3.0-patched/jemalloc"
                         "vendor/jemalloc-sys-0.5.4+5.3.0-patched/jemalloc"
                         "vendor/openssl-src-111.28.2+1.1.1w/openssl"
                         "vendor/tikv-jemalloc-sys-0.5.4+5.3.0-patched/jemalloc"))
             ;; Remove vendored dynamically linked libraries.
             ;; find . -not -type d -executable -exec file {} \+ | grep ELF
             ;; Also remove the bundled (mostly Windows) libraries.
             (for-each delete-file
                       (find-files "vendor" "\\.(a|dll|exe|lib)$"))
             ;; Adjust vendored dependency to explicitly use rustix with libc backend.
             (substitute* '("vendor/tempfile-3.7.1/Cargo.toml"
                            "vendor/tempfile-3.10.1/Cargo.toml")
               (("features = \\[\"fs\"" all)
                (string-append all ", \"use-libc\""))))))))))

(define-public rust-1.81
  (let ((base-rust (rust-bootstrapped-package rust-1.80 "1.81.0"
                                              "19yggj1qivdhf68gx2652cfi7nxjkdgy39wh7h6facpzppz4h947")))
    (package
      (inherit base-rust))))

(define (make-ignore-test-list strs)
  "Function to make creating a list to ignore tests a bit easier."
  (map (lambda (str)
    `((,str) (string-append "#[ignore]\n" ,str)))
    strs))

(define-public rust-1.82
  (let ((base-rust (rust-bootstrapped-package rust-1.81 "1.82.0"
                                              "0ajiryki2aqsg3ydx3nfhrb5i1mmxvasfszs9qblw66skr8g8lvw")))
    (package
      (inherit base-rust)
      (arguments
       (substitute-keyword-arguments (package-arguments base-rust)
         ((#:phases phases)
          `(modify-phases ,phases
             (replace 'patch-cargo-checksums
               (lambda _
                 (substitute* (cons* "Cargo.lock"
                                     "src/bootstrap/Cargo.lock"
                                     "library/Cargo.lock"
                                     (filter
                                      ;; don't mess with the
                                      ;; lock files in the Cargo testsuite; it
                                      ;; messes up the tests.
                                      (lambda (path)
                                        (not
                                         (string-contains path "cargo/tests/testsuite")))
                                      (find-files "src/tools" "Cargo.lock")))
                   (("(checksum = )\".*\"" all name)
                    (string-append name "\"" ,%cargo-reference-hash "\"")))
                 (generate-all-checksums "vendor"))))))))))

(define (make-supported-rust base-rust)
  (package
    (inherit base-rust)
    (properties (append
                 (alist-delete 'hidden? (package-properties base-rust))
                 (clang-compiler-cpu-architectures "17")))
    (outputs (cons* "rust-src" "tools" (package-outputs base-rust)))
    (source
     (origin
       (inherit (package-source base-rust))
       (snippet
        '(begin
           (for-each delete-file-recursively
                     '("src/llvm-project"
                       "vendor/jemalloc-sys-0.5.3+5.3.0-patched/jemalloc"
                       "vendor/jemalloc-sys-0.5.4+5.3.0-patched/jemalloc"
                       "vendor/openssl-src-111.17.0+1.1.1m/openssl"
                       "vendor/openssl-src-111.28.2+1.1.1w/openssl"
                       "vendor/tikv-jemalloc-sys-0.5.4+5.3.0-patched/jemalloc"
                       ;; These are referenced by the cargo output
                       ;; so we unbundle them.
                       "vendor/curl-sys-0.4.52+curl-7.81.0/curl"
                       "vendor/curl-sys-0.4.74+curl-8.9.0/curl"
                       "vendor/libffi-sys-2.3.0/libffi"
                       "vendor/libz-sys-1.1.3/src/zlib"
                       "vendor/libz-sys-1.1.18/src/zlib"
                       "vendor/libz-sys-1.1.19/src/zlib"))
           ;; Use the packaged nghttp2
           (for-each
            (lambda (ver)
              (let ((vendored-dir (format #f "vendor/libnghttp2-sys-~a/nghttp2" ver))
                    (build-rs (format #f "vendor/libnghttp2-sys-~a/build.rs" ver)))
                (delete-file-recursively vendored-dir)
                (delete-file build-rs)
                (with-output-to-file build-rs
                  (lambda _
                    (format #t "fn main() {~@
                         println!(\"cargo:rustc-link-lib=nghttp2\");~@
                         }~%")))))
            '("0.1.10+1.61.0"
              "0.1.7+1.45.0"))
           ;; Remove vendored dynamically linked libraries.
           ;; find . -not -type d -executable -exec file {} \+ | grep ELF
           ;; Also remove the bundled (mostly Windows) libraries.
           (for-each delete-file
                     (find-files "vendor" "\\.(a|dll|exe|lib)$"))
           ;; Adjust vendored dependency to explicitly use rustix with libc backend.
           (for-each
            (lambda (ver)
              (let ((f (format #f "vendor/tempfile-~a/Cargo.toml" ver)))
                (substitute* f
                  (("features = \\[\"fs\"" all)
                   (string-append all ", \"use-libc\"")))))
            '("3.3.0"
              "3.4.0"
              "3.7.1"
              "3.10.1"
              "3.12.0"))))))
    (arguments
     (substitute-keyword-arguments
         (strip-keyword-arguments '(#:tests?)
                                  (package-arguments base-rust))
       ((#:phases phases)
        `(modify-phases ,phases
           (add-after 'unpack 'relax-gdb-auto-load-safe-path
             ;; Allow GDB to load binaries from any location, otherwise the
             ;; gdbinfo tests fail.  This is only useful when testing with a
             ;; GDB version newer than 8.2.
             (lambda _
               (setenv "HOME" (getcwd))
               (with-output-to-file (string-append (getenv "HOME") "/.gdbinit")
                 (lambda _
                   (format #t "set auto-load safe-path /~%")))
               ;; Do not launch gdb with '-nx' which causes it to not execute
               ;; any init file.
               (substitute* "src/tools/compiletest/src/runtest.rs"
                 (("\"-nx\".as_ref\\(\\), ")
                  ""))))
           (add-after 'unpack 'disable-tests-requiring-git
             (lambda _
               (substitute* "src/tools/cargo/tests/testsuite/git.rs"
                 ,@(make-ignore-test-list
                    '("fn fetch_downloads_with_git2_first_")))
               (substitute* "src/tools/cargo/tests/testsuite/build.rs"
                 ,@(make-ignore-test-list
                    '("fn build_with_symlink_to_path_dependency_with_build_script_in_git")))
               (substitute* "src/tools/cargo/tests/testsuite/publish_lockfile.rs"
                 ,@(make-ignore-test-list
                    '("fn note_resolve_changes")))))
           (add-after 'unpack 'disable-tests-requiring-mercurial
             (lambda _
               (with-directory-excursion "src/tools/cargo/tests/testsuite/cargo_init"
                 (substitute* '("mercurial_autodetect/mod.rs"
                                "simple_hg_ignore_exists/mod.rs")
                   ,@(make-ignore-test-list
                      '("fn case"))))))
           (add-after 'unpack 'disable-tests-using-cargo-publish
             (lambda _
               (with-directory-excursion "src/tools/cargo/tests/testsuite"
                 (substitute* "alt_registry.rs"
                   ,@(make-ignore-test-list
                      '("fn warn_for_unused_fields")))
                 (substitute* '("cargo_add/locked_unchanged/mod.rs"
                                "cargo_add/lockfile_updated/mod.rs"
                                "cargo_remove/update_lock_file/mod.rs")
                   ,@(make-ignore-test-list
                      '("fn case")))
                 (substitute* "git_shallow.rs"
                   ,@(make-ignore-test-list
                      '("fn gitoxide_clones_git_dependency_with_shallow_protocol_and_git2_is_used_for_followup_fetches"
                        "fn gitoxide_clones_registry_with_shallow_protocol_and_aborts_and_updates_again"
                        "fn gitoxide_clones_registry_with_shallow_protocol_and_follow_up_fetch_maintains_shallowness"
                        "fn gitoxide_clones_registry_with_shallow_protocol_and_follow_up_with_git2_fetch"
                        "fn gitoxide_clones_registry_without_shallow_protocol_and_follow_up_fetch_uses_shallowness"
                        "fn gitoxide_shallow_clone_followed_by_non_shallow_update"
                        "fn gitoxide_clones_shallow_two_revs_same_deps"
                        "fn gitoxide_git_dependencies_switch_from_branch_to_rev"
                        "fn shallow_deps_work_with_revisions_and_branches_mixed_on_same_dependency")))
                 (substitute* "install.rs"
                   ,@(make-ignore-test-list
                      '("fn failed_install_retains_temp_directory")))
                 (substitute* "offline.rs"
                   ,@(make-ignore-test-list
                      '("fn gitoxide_cargo_compile_offline_with_cached_git_dep_shallow_dep")))
                 (substitute* "patch.rs"
                   ,@(make-ignore-test-list
                      '("fn gitoxide_clones_shallow_old_git_patch"))))))
           ,@(if (target-riscv64?)
                 ;; Keep this phase separate so it can be adjusted without needing
                 ;; to adjust the skipped tests on other architectures.
                 `((add-after 'unpack 'disable-tests-broken-on-riscv64
                     (lambda _
                       (with-directory-excursion "src/tools/cargo/tests/testsuite"
                         (substitute* "build.rs"
                           ,@(make-ignore-test-list
                              '("fn uplift_dwp_of_bin_on_linux")))
                         (substitute* "cache_lock.rs"
                           ,@(make-ignore-test-list
                              '("fn multiple_shared"
                                "fn multiple_download"
                                "fn download_then_mutate")))
                         (substitute* "global_cache_tracker.rs"
                           ,@(make-ignore-test-list
                              '("fn package_cache_lock_during_build")))))))
                 `())
           (add-after 'unpack 'disable-tests-broken-on-aarch64
             (lambda _
               (with-directory-excursion "src/tools/cargo/tests/testsuite/"
                 (substitute* "build_script_extra_link_arg.rs"
                   ,@(make-ignore-test-list
                      '("fn build_script_extra_link_arg_bin_single")))
                 (substitute* "build_script.rs"
                   ,@(make-ignore-test-list
                      '("fn env_test")))
                 (substitute* "collisions.rs"
                   ,@(make-ignore-test-list
                      '("fn collision_doc_profile_split")))
                 (substitute* "concurrent.rs"
                   ,@(make-ignore-test-list
                      '("fn no_deadlock_with_git_dependencies")))
                 (substitute* "features2.rs"
                   ,@(make-ignore-test-list
                      '("fn dep_with_optional_host_deps_activated"))))))
           (add-after 'unpack 'disable-tests-requiring-crates.io
             (lambda _
               (substitute* "src/tools/cargo/tests/testsuite/install.rs"
                 ,@(make-ignore-test-list
                    '("fn install_global_cargo_config")))
               (substitute* "src/tools/cargo/tests/testsuite/cargo_info/within_ws_with_alternative_registry/mod.rs"
                 ,@(make-ignore-test-list
                    '("fn case")))
               (substitute* "src/tools/cargo/tests/testsuite/package.rs"
                 ,@(make-ignore-test-list
                    '("fn workspace_with_local_deps_index_mismatch")))))
           (add-after 'unpack 'disable-miscellaneous-broken-tests
             (lambda _
               (substitute* "src/tools/cargo/tests/testsuite/check_cfg.rs"
                 ;; These apparently get confused by the fact that
                 ;; we're building in a directory containing the
                 ;; string "rustc"
                 ,@(make-ignore-test-list
                    '("fn config_fingerprint"
                      "fn features_fingerprint")))
               (substitute* "src/tools/cargo/tests/testsuite/git_auth.rs"
                 ;; This checks for a specific networking error message
                 ;; that's different from the one we see in the builder
                 ,@(make-ignore-test-list
                    '("fn net_err_suggests_fetch_with_cli")))))
           (add-after 'unpack 'patch-command-exec-tests
             ;; This test suite includes some tests that the stdlib's
             ;; `Command` execution properly handles in situations where
             ;; the environment or PATH variable are empty, but this fails
             ;; since we don't have `echo` available at its usual FHS
             ;; location.
             (lambda _
               (substitute* "tests/ui/command/command-exec.rs"
                 (("Command::new\\(\"echo\"\\)")
                  (format #f "Command::new(~s)" (which "echo"))))))
           (add-after 'unpack 'patch-command-uid-gid-test
             (lambda _
               (substitute* "tests/ui/command/command-uid-gid.rs"
                 (("/bin/sh") (which "sh"))
                 (("/bin/ls") (which "ls")))))
           (add-after 'unpack 'skip-shebang-tests
             ;; This test make sure that the parser behaves properly when a
             ;; source file starts with a shebang. Unfortunately, the
             ;; patch-shebangs phase changes the meaning of these edge-cases.
             ;; We skip the test since it's drastically unlikely Guix's
             ;; packaging will introduce a bug here.
             (lambda _
               (delete-file "tests/ui/parser/shebang/sneaky-attrib.rs")))
           (add-after 'unpack 'patch-process-tests
             (lambda* (#:key inputs #:allow-other-keys)
               (let ((bash (assoc-ref inputs "bash")))
                 (with-directory-excursion "library/std/src"
                   (substitute* "process/tests.rs"
                     (("\"/bin/sh\"")
                      (string-append "\"" bash "/bin/sh\"")))
                   ;; The three tests which are known to fail upstream on QEMU
                   ;; emulation on aarch64 and riscv64 also fail on x86_64 in
                   ;; Guix's build system.  Skip them on all builds.
                   (substitute* "sys/pal/unix/process/process_common/tests.rs"
                     ;; We can't use make-ignore-test-list because we will get
                     ;; build errors due to the double [ignore] block.
                     (("target_arch = \"arm\"" arm)
                      (string-append "target_os = \"linux\",\n"
                                     "        " arm)))))))
           (add-after 'unpack 'disable-interrupt-tests
             (lambda _
               ;; This test hangs in the build container; disable it.
               (substitute* "src/tools/cargo/tests/testsuite/freshness.rs"
                 ,@(make-ignore-test-list
                    '("fn linking_interrupted")))
               ;; Likewise for the ctrl_c_kills_everyone test.
               (substitute* "src/tools/cargo/tests/testsuite/death.rs"
                 ,@(make-ignore-test-list
                    '("fn ctrl_c_kills_everyone")))))
           (add-after 'unpack 'adjust-rpath-values
             ;; This adds %output:out to rpath, allowing us to install utilities in
             ;; different outputs while reusing the shared libraries.
             (lambda* (#:key outputs #:allow-other-keys)
               (let ((out (assoc-ref outputs "out")))
                 (substitute* "src/bootstrap/src/core/builder.rs"
                   ((" = rpath.*" all)
                    (string-append all
                                   "                "
                                   "self.rustflags.arg(\"-Clink-args=-Wl,-rpath="
                                   out "/lib\");\n"))))))
           (add-after 'unpack 'unpack-profiler-rt
             ;; Copy compiler-rt sources to where libprofiler_builtins looks
             ;; for its vendored copy.
             (lambda* (#:key inputs #:allow-other-keys)
               (mkdir-p "src/llvm-project/compiler-rt")
               (copy-recursively
                (string-append (assoc-ref inputs "clang-source")
                               "/compiler-rt")
                "src/llvm-project/compiler-rt")))
           (add-after 'configure 'enable-profiling
             (lambda _
               (substitute* "config.toml"
                 (("^profiler =.*$") "")
                 (("\\[build\\]") "\n[build]\nprofiler = true\n"))))
           (add-after 'configure 'add-gdb-to-config
             (lambda* (#:key inputs #:allow-other-keys)
               (let ((gdb (assoc-ref inputs "gdb")))
                 (substitute* "config.toml"
                   (("^python =.*" all)
                    (string-append all
                                   "gdb = \"" gdb "/bin/gdb\"\n"))))))
           (replace 'build
             ;; Phase overridden to also build more tools.
             (lambda* (#:key parallel-build? #:allow-other-keys)
               (let ((job-spec (string-append
                                "-j" (if parallel-build?
                                         (number->string (parallel-job-count))
                                         "1"))))
                 (invoke "./x.py" job-spec "build"
                         "library/std"    ;rustc
                         "src/tools/cargo"
                         "src/tools/clippy"
                         "src/tools/rust-analyzer"
                         "src/tools/rust-analyzer/crates/proc-macro-srv-cli"
                         "src/tools/rustfmt"))
               ))
           (replace 'check
             ;; Phase overridden to also test more tools.
             (lambda* (#:key tests? parallel-build? #:allow-other-keys)
               (when tests?
                 (let ((job-spec (string-append
                                  "-j" (if parallel-build?
                                           (number->string (parallel-job-count))
                                           "1"))))
                   (invoke "./x.py" job-spec "test" "-vv"
                           "library/std"
                           "src/tools/cargo"
                           "src/tools/clippy"
                           "src/tools/rust-analyzer"
                           "src/tools/rustfmt")))))
           (replace 'install
             ;; Phase overridden to also install more tools.
             (lambda* (#:key outputs #:allow-other-keys)
               (invoke "./x.py" "install")
               (substitute* "config.toml"
                 ;; Adjust the prefix to the 'cargo' output.
                 (("prefix = \"[^\"]*\"")
                  (format #f "prefix = ~s" (assoc-ref outputs "cargo"))))
               (invoke "./x.py" "install" "cargo")
               (substitute* "config.toml"
                 ;; Adjust the prefix to the 'tools' output.
                 (("prefix = \"[^\"]*\"")
                  (format #f "prefix = ~s" (assoc-ref outputs "tools"))))
               (invoke "./x.py" "install" "clippy")
               (invoke "./x.py" "install" "rust-analyzer")
               (invoke "./x.py" "install" "rustfmt")
               ;; ./x.py doesn't have an install target
               ;; for the proc macro server, so we install it manually
               (let* ((out (assoc-ref outputs "out"))
                      (platform ,(platform-rust-target
                                  (lookup-platform-by-target-or-system
                                   (or (%current-target-system)
                                       (%current-system))))))
                 (install-file (string-append "build/" platform "/stage2-tools/" platform "/release/rust-analyzer-proc-macro-srv")
                               (string-append out "/libexec")))))
           (add-after 'install 'install-rust-src
             (lambda* (#:key outputs #:allow-other-keys)
               (let ((out (assoc-ref outputs "rust-src"))
                     (dest "/lib/rustlib/src/rust"))
                 (mkdir-p (string-append out dest))
                 (copy-recursively "library" (string-append out dest "/library"))
                 (copy-recursively "src" (string-append out dest "/src")))))
           (add-after 'install 'remove-uninstall-script
             (lambda* (#:key outputs #:allow-other-keys)
               ;; This script has no use on Guix
               ;; and it retains a reference to the host's bash.
               (delete-file (string-append (assoc-ref outputs "out")
                                           "/lib/rustlib/uninstall.sh"))))
           (add-after 'install-rust-src 'wrap-rust-analyzer
             (lambda* (#:key outputs #:allow-other-keys)
               (let ((bin (string-append (assoc-ref outputs "tools") "/bin")))
                 (rename-file (string-append bin "/rust-analyzer")
                              (string-append bin "/.rust-analyzer-real"))
                 (call-with-output-file (string-append bin "/rust-analyzer")
                   (lambda (port)
                     (format port "#!~a
if test -z \"${RUST_SRC_PATH}\";then export RUST_SRC_PATH=~S;fi;
exec -a \"$0\" \"~a\" \"$@\""
                             (which "bash")
                             (string-append (assoc-ref outputs "rust-src")
                                            "/lib/rustlib/src/rust/library")
                             (string-append bin "/.rust-analyzer-real"))))
                 (chmod (string-append bin "/rust-analyzer") #o755))))))))
    (inputs
     (modify-inputs (package-inputs base-rust)
       (prepend curl libffi `(,nghttp2 "lib") zlib)))
    ;; Add test inputs.
    (native-inputs (cons*
                    ;; Keep in sync with the llvm used to build rust.
                    `("clang-source" ,(package-source clang-runtime-17))
                    `("gdb" ,gdb/pinned)
                    `("procps" ,procps)
                    (package-native-inputs base-rust)))))

(define-public rust-next
  (let ((p (make-supported-rust rust-1.82)))
    (package
      (inherit p)
      (name "rust-next"))))