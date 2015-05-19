###0.6.2
 * Support observatory protocol changes for VM >= 1.11.0.

###0.6.1
 * Support observatory protocol changes for VM >= 1.10.0.

###0.6.0+1
 * Add support for `pub global run`.

###0.6.0
  * Add support for SDK versions >= 1.9.0. For Dartium/content-shell versions
    past 1.9.0, coverage collection is no longer done over the remote debugging
    port, but via the observatory port emitted on stdout. Backward
    compatibility with SDKs back to 1.5.x is provided.
