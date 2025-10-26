FORMULA_RENAMES = {
  "app-engine-java-sdk" => "app-engine-java",
  "cv"                  => "progress",
  "fig"                 => "docker-compose",
  'gnupg2'              => 'gnupg',
  "go-app-engine-32"    => "app-engine-go-32",
  "go-app-engine-64"    => "app-engine-go-64",
  "google-perftools"    => "gperftools",
  "google-app-engine"   => "app-engine-python",
  "libcppa"             => "caf",
  'kerberos-v5'         => 'kerberos',
  "mpich2"              => "mpich",
  "objective-caml"      => "ocaml",
  "python"              => "python2",
  "plt-racket"          => "racket",
}

FORMULA_SUBSUMPTIONS = {
  'gnupg' => ['dirmngr',
              'gnupg2',
              'gpg-agent'],
}
