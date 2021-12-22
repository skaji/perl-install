# perl-install

![](https://raw.githubusercontent.com/skaji/images/master/perl-install.png)

Build and install perls.

This is similar to [perl-build](https://github.com/tokuhirom/Perl-Build).
While perl-build is written in perl, perl-install is written in shell script.

perl-install also provides [plenv](https://github.com/tokuhirom/plenv) `install` command.

# Install

```console
❯ git clone https://github.com/skaji/perl-install
```

If you want to use perl-install as a [plenv](https://github.com/tokuhirom/plenv) plugin, then change the target directory:

```console
❯ git clone https://github.com/skaji/perl-install $(plenv root)/plugins/perl-install
```

Note that if you already have perl-build in your plenv plugin directory, then remove it first.

# Usage

```console
❯ perl-install --help
Usage: perl-install [options] perl_version prefix

Options:
  -A, -D, -U       set perl configure options
  -l, --list       list stable perl versions, and exit
  -L, --list-all   list all perl versions, and exit
  -j, --jobs       set make --jobs option
  -h, --help       show this help
      --version    show perl-install's version
      --man        generate man pages
      --nopatch    do not apply Devel::PatchPerl
      --test       run test
      --work-dir   set work directory

Examples:
  $ perl-install -l
  $ perl-install latest ~/perl
  $ perl-install 5.30.1 ~/perl
  $ perl-install 5.30.1 ~/perl-shrplib -Duseithreads -Duseshrplib
```

# Requirements

To use perl-install, you need:

* curl/wget
* tar
* patch

To build perl, you need:

* make
* c compiler, such as gcc
* c headers

# License

This software is copyright (c) 2019 by Shoichi Kaji <skaji@cpan.org>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
