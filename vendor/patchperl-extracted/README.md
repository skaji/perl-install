# patchperl extracted

Collection of patch files for old perls.
These patch files are extracted from [Devel::PatchPerl](https://metacpan.org/pod/Devel::PatchPerl).

# Why not Devel::PatchPerl?

Devel::PatchPerl allows us to build/install old perls into recent OS.
I always use it, and it's very useful. Thanks Bingos for creating and maintaining Devel::PatchPerl.

It is written in perl. Unfortunately, these days, we cannot assume that there already exists *system* perl *before* installing perl.
In fact, Apple announced that scripting language runtimes including perl wouldn't be available by default in future versions of macOS
([see this](https://developer.apple.com/documentation/xcode_release_notes/xcode_11_release_notes)).

So I think it is useful there exist plain patch files for old perls.

# Install

```
# if you have git, then:
git clone https://github.com/skaji/patchperl-extracted

# otherwise;
curl -fsSL -o patchperl-extracted-main.tar.gz https://github.com/skaji/patchperl-extracted/archive/main.tar.gz
tar xzf patchperl-extracted-main.tar.gz
```

# Usage

Let's say you want to build perl 5.8.1. Then:

```
# Step 1. Download perl-5.8.1 source code
curl -fsSL -o perl-5.8.1.tar.gz https://www.cpan.org/src/5.0/perl-5.8.1.tar.gz
tar xzf perl-5.8.1.tar.gz
cd perl-5.8.1

# Step 2. Patch perl-5.8.1 with patchperl
/path/to/patchperl-extracted/patchperl 5.8.1

# Step 3. Build perl as usual
./Configure -des -Dprefix=$HOME/perl-5.8.1 -Dscriptdir=$HOME/perl-5.8.1/bin
make
make install
```

# License

This software is copyright (c) 2019 by Shoichi Kaji.

This is free software;
you can redistribute it and/or modify it under the same terms
as [Devel::PatchPerl](https://metacpan.org/pod/Devel::PatchPerl).
