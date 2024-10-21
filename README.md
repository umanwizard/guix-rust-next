Guix packages for recent rust (currently: rust 1.82.0)

To get this channel, add this to your channels list:

``` scheme
(channel
 (name 'rust-next)
 (url "https://github.com/umanwizard/guix-rust-next")
 (branch "main")
 (introduction
 (make-channel-introduction
  "72e021c9a90f9f417bdffca8799c8d3e0aa98a72"
  (openpgp-fingerprint
   "9E53FC33B8328C745E7B31F70226C10D7877B741"))))
```

For example, if you also use `nonguix`, the full contents of your `~/.config/guix/channels.scm` might look like:

``` scheme
(cons* (channel
        (name 'rust-next)
        (url "https://github.com/umanwizard/guix-rust-next")
        (branch "main")
        (introduction
         (make-channel-introduction
          "72e021c9a90f9f417bdffca8799c8d3e0aa98a72"
          (openpgp-fingerprint
           "9E53FC33B8328C745E7B31F70226C10D7877B741"))))
       (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        (branch "master")
        (introduction
         (make-channel-introduction
          "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
          (openpgp-fingerprint
           "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
      %default-channels)
```

After making the change to your channels list, run `guix pull`.

Everything is in the module `(btv rust)`.
