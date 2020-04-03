#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/local/lib/perl5";
use Devel::PatchPerl;
use Devel::PatchPerl::Hints ();

use CPAN::Perl::Releases;
use File::Path 'make_path';
use File::Slurper 'write_binary';
use HTTP::Tiny;
use Sub::Util 'subname';
use version;

our $VERSION = '0.0.2';

chdir "$FindBin::Bin/..";

{
    write_binary "version", <<END
Devel::PatchPerl $Devel::PatchPerl::VERSION (patchperl-extracted $VERSION)
END
}

our $PATCH_FILE = ""; {
    no warnings 'redefine';
    *Devel::PatchPerl::_patch = sub {
        my ($content) = @_;
        open my $fh, ">", $PATCH_FILE or die;
        print {$fh} $content;
    };
}

my @PATCH = do { no warnings; @Devel::PatchPerl::patch; };

my @PERL_VERSION =
    sort { version->parse($a) <=> version->parse($b) }
    grep { version->parse($_) >= 5.008_001 }
    grep { /5\.\d+\.\d+$/ }
    keys %$CPAN::Perl::Releases::data;

my %KNOWN = map { ("Devel::PatchPerl::$_", 1) } qw(
    _patch_patchlevel
    _patch_hints
    _patch_db
    _patch_doio
    _patch_sysv
    _patch_configure
    _patch_makedepend_lc
    _patch_makedepend_SH
    _patch_conf_gconvert
    _patch_sort_N
    _patch_archive_tar_tests
    _patch_odbm_file_hints_linux
    _patch_make_ext_pl
    _patch_589_perlio_c
    _patch_hsplit_rehash_58
    _patch_hsplit_rehash_510
    _patch_bitrig
    _patch_conf_solaris
    _patch_regmatch_pointer_5180
    _patch_makefile_sh_phony
    _patch_cow_speed
    _patch_preprocess_options
    _patch_5183_metajson
    _patch_handy
    _patch_5_005_02
    _patch_5_005_01
    _patch_5_005
    _patch_errno_gcc5
    _patch_time_hires
    _patch_fp_class_denorm
    _patch_develpatchperlversion
    _patch_conf_fwrapv
    _patch_utils_h2ph
    _patch_lib_h2ph
    _patch_sdbm_file_c
    _patch_mmaix_pm
    _patch_time_local_t
);

my @skip = qw(develpatchperlversion sysv patchlevel hints bitrig conf_solaris);

for my $perl_version (@PERL_VERSION) {
    make_path "patch/$perl_version/all" if !-d "$perl_version/all";
    for my $patch (@PATCH) {
        my @perl = @{ $patch->{perl} };
        next if !grep { $perl_version =~ $_ } @perl;
        my @sub = @{ $patch->{subs} };
        for my $sub (@sub) {
            my ($sub, @argv) = @$sub;
            my $name = subname $sub;
            if (!$KNOWN{$name}++) {
                warn "---> found new patch: $name\n";
            }
            $name =~ s/Devel::PatchPerl::_patch_//;
            next if grep { $name eq $_ } @skip;
            local $PATCH_FILE = "patch/$perl_version/all/$name.patch";
            $sub->($perl_version, @argv);
        }
    }
}

{
  my $dpv = $Devel::PatchPerl::VERSION;
  my $patch = <<"END";
diff --git a/Configure b/Configure
index e12c8bb..1a8088f 100755
--- Configure
+++ Configure
@@ -25151,6 +25151,8 @@ zcat='\$zcat'
 zip='\$zip'
 EOT
 
+echo "BuiltWithPatchPerl='$dpv'" >>config.sh
+
 : add special variables
 \$test -f \$src/patchlevel.h && \
 awk '/^#define[ 	]+PERL_/ {printf "\%s=\%s\\n",\$2,\$3}' \$src/patchlevel.h >>config.sh
END
  for my $perl_version (@PERL_VERSION) {
      write_binary "patch/$perl_version/all/develpatchperlversion.patch", $patch;
  }
}

{
    my $http = HTTP::Tiny->new(verify_SSL => 1);
    make_path "maint/patchlevel" if !-d "maint/patchlevel";
    for my $perl_version (@PERL_VERSION) {
        my $file = "maint/patchlevel/$perl_version";
        if (!-f $file) {
            my $tag = $perl_version =~ /^5.[89]\./ ? "perl-$perl_version" : "v$perl_version";
            my $url = "https://raw.githubusercontent.com/Perl/perl5/$tag/patchlevel.h";
            warn "Downloading $url\n";
            my $res = $http->mirror($url => $file);
            die "$res->{status} $res->{reason}, $url\n" if !$res->{success};
        }
        open my $fh, "<", $file or die;
        my $i;
        my $seen;
        while (<$fh>) {
            if (/\t,NULL/ and $seen) {
                $i = $fh->input_line_number;
                last;
            }
            $seen++ if /local_patches\[\]/;
        }
        my $patch = sprintf <<'END', $i-1, $i, $Devel::PatchPerl::VERSION, $VERSION;
--- patchlevel.h.org	2019-11-22 00:38:51.000000000 +0900
+++ patchlevel.h	2019-11-22 00:39:12.000000000 +0900
@@ -%d,0 +%d @@
+	,"Devel::PatchPerl %s (patchperl-extracted %s)"
END
        write_binary "patch/$perl_version/all/patchlevel.patch", $patch;
    }
}

{
    my @os = Devel::PatchPerl::Hints::hints;
    make_path "hints" if !-d "hints";
    for my $os (@os) {
        my ($path, $c) = Devel::PatchPerl::Hints::hint_file $os;
        write_binary "hints/$path", $c;
    }
}

sub conditional_patch {
    my ($name, $perl_version_check, $condition, $patch) = @_;
    for my $perl_version (@PERL_VERSION) {
        next if !$perl_version_check->($perl_version);
        my $dir = "patch/$perl_version/conditional/$name";
        make_path $dir if !-d $dir;
        write_binary "$dir/condition", $condition;
        write_binary "$dir/patch", $patch;
    }
}

{
    my $condition = <<'END';
[ $(uname) = Linux ] && [ ! -f /usr/include/asm/page.h ]
END
    my $patch = <<'END';
--- ext/IPC/SysV/SysV.xs.org  2007-08-11 00:12:46.000000000 +0200
+++ ext/IPC/SysV/SysV.xs  2007-08-11 00:10:51.000000000 +0200
@@ -3,9 +3,6 @@
 #include "XSUB.h"
 
 #include <sys/types.h>
-#ifdef __linux__
-#   include <asm/page.h>
-#endif
 #if defined(HAS_MSG) || defined(HAS_SEM) || defined(HAS_SHM)
 #ifndef HAS_SEM
 #   include <sys/ipc.h>
END
    my $perl_version_check = sub {
        my $perl_version = shift;
        my @perl = (qr/^5\.8\.[0-8]$/, qr/^5\.9\.[0-5]$/);
        scalar grep { $perl_version =~ $_ } @perl;
    };
    conditional_patch "sysv", $perl_version_check, $condition, $patch;
}

my $SOLARIS_CONDITION = <<'END';
myuname=$(uname -s | tr '[A-Z]' '[a-z]')
if [[ $myuname = solaris ]]; then
  exit 0
elif [[ $myuname = sunos ]]; then
  if [[ $(uname -r) =~ ^5 ]]; then
    exit 0
  fi
fi
exit 1
END
{
    my $patch = <<'END';
diff --git a/Configure b/Configure
index ff511d3..30ab78a 100755
--- Configure
+++ Configure
@@ -8048,7 +8048,20 @@ EOM
 			      ;;
 			linux|irix*|gnu*)  dflt="-shared $optimize" ;;
 			next)  dflt='none' ;;
-			solaris) dflt='-G' ;;
+			solaris) # See [perl #66604].  On Solaris 11, gcc -m64 on amd64
+				# appears not to understand -G.  gcc versions at
+				# least as old as 3.4.3 support -shared, so just
+				# use that with Solaris 11 and later, but keep
+				# the old behavior for older Solaris versions.
+				case "$gccversion" in
+					'') dflt='-G' ;;
+					*)	case "$osvers" in
+							2.?|2.10) dflt='-G' ;;
+							*) dflt='-shared' ;;
+						esac
+						;;
+				esac
+				;;
 			sunos) dflt='-assert nodefinitions' ;;
 			svr4*|esix*|nonstopux) dflt="-G $ldflags" ;;
 	        *)     dflt='none' ;;
END
    my $perl_version_check = sub {
        my $perl_version = shift;
        return version->parse($perl_version) < 5.018000;
        return 1;
    };
    conditional_patch "conf_solaris", $perl_version_check, $SOLARIS_CONDITION, $patch;
}

my $BITRIG_CONDITION = <<'END';
[[ $(uname -s) = Bitrig ]]
END
{
    my $patch = <<'END';
diff --git a/Configure b/Configure
index 19bed50..e4e4075 100755
--- Configure
+++ Configure
@@ -3312,6 +3312,9 @@ EOM
 			;;
 		next*) osname=next ;;
 		nonstop-ux) osname=nonstopux ;;
+		bitrig) osname=bitrig
+			osvers="$3"
+			;;
 		openbsd) osname=openbsd
                 	osvers="$3"
                 	;;
END
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if $perl_version >= 5.019004;
        return 1;
    };
    conditional_patch "bitrig_boogle", $perl_version_check, $BITRIG_CONDITION, $patch;
}
{
    my $patch = <<'END';
diff --git a/Makefile.SH b/Makefile.SH
index 17298fa..ecaa8ac 100755
--- Makefile.SH
+++ Makefile.SH
@@ -77,7 +77,7 @@ true)
 	sunos*)
 		linklibperl="-lperl"
 		;;
-	netbsd*|freebsd[234]*|openbsd*)
+	netbsd*|freebsd[234]*|openbsd*|bitrig*)
 		linklibperl="-L. -lperl"
 		;;
 	interix*)
END
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if $perl_version >= 5.019004;
        $perl_version < 5.008009;
    };
    conditional_patch "bitrig_bitrigm1", $perl_version_check, $BITRIG_CONDITION, $patch;
}
{
    my $patch = <<'END';
diff --git a/Makefile.SH b/Makefile.SH
index 17298fa..ecaa8ac 100755
--- Makefile.SH
+++ Makefile.SH
@@ -77,7 +77,7 @@ true)
 	sunos*)
 		linklibperl="-lperl"
 		;;
-	netbsd*|freebsd[234]*|openbsd*|dragonfly*)
+	netbsd*|freebsd[234]*|openbsd*|dragonfly*|bitrig*)
 		linklibperl="-L. -lperl"
 		;;
 	interix*)
END
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if $perl_version >= 5.019004;
        $perl_version >= 5.008009;
    };
    conditional_patch "bitrig_bitrigmx", $perl_version_check, $BITRIG_CONDITION, $patch;
}
{
    my $patch = <<'END';
diff --git a/Configure b/Configure
index 19bed50..e4e4075 100755
--- Configure	Thu Aug 22 23:20:14 2013
+++ Configure	Thu Aug 22 23:20:35 2013
@@ -7855,7 +7855,7 @@
 	solaris)
 		xxx="-R $shrpdir"
 		;;
-	freebsd|netbsd|openbsd)
+	freebsd|netbsd|openbsd|bitrig)
 		xxx="-Wl,-R$shrpdir"
 		;;
 	bsdos|linux|irix*|dec_osf)
END
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if $perl_version >= 5.019004;
        5.008001 <= $perl_version && $perl_version < 5.008007;
    };
    conditional_patch "bitrig_bitrigc3", $perl_version_check, $BITRIG_CONDITION, $patch;
}
{
    my $patch = <<'END';
diff --git a/Configure b/Configure
index 19bed50..e4e4075 100755
--- Configure	Thu Aug 22 22:56:04 2013
+++ Configure	Thu Aug 22 22:56:25 2013
@@ -7892,7 +7892,7 @@
 	solaris)
 		xxx="-R $shrpdir"
 		;;
-	freebsd|netbsd|openbsd|interix)
+	freebsd|netbsd|openbsd|interix|bitrig)
 		xxx="-Wl,-R$shrpdir"
 		;;
 	bsdos|linux|irix*|dec_osf|gnu*)
END
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if $perl_version >= 5.019004;
        5.008007 <= $perl_version && $perl_version < 5.008009;
    };
    conditional_patch "bitrig_bitrigc2", $perl_version_check, $BITRIG_CONDITION, $patch;
}
{
    my $patch = <<'END';
diff --git a/Configure b/Configure
index 19bed50..e4e4075 100755
--- Configure
+++ Configure
@@ -8328,7 +8331,7 @@ if "$useshrplib"; then
 	solaris)
 		xxx="-R $shrpdir"
 		;;
-	freebsd|netbsd|openbsd|interix|dragonfly)
+	freebsd|netbsd|openbsd|interix|dragonfly|bitrig)
 		xxx="-Wl,-R$shrpdir"
 		;;
 	bsdos|linux|irix*|dec_osf|gnu*)
END
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if $perl_version >= 5.019004;
        5.008009 <= $perl_version && $perl_version < 5.013000;
    };
    conditional_patch "bitrig_bitrigc1", $perl_version_check, $BITRIG_CONDITION, $patch;
}
{
    my $patch = <<'END';
diff --git a/Configure b/Configure
index 19bed50..e4e4075 100755
--- Configure
+++ Configure
@@ -8328,7 +8331,7 @@ if "$useshrplib"; then
 	solaris)
 		xxx="-R $shrpdir"
 		;;
-	freebsd|mirbsd|netbsd|openbsd|interix|dragonfly)
+	freebsd|mirbsd|netbsd|openbsd|interix|dragonfly|bitrig)
 		xxx="-Wl,-R$shrpdir"
 		;;
 	bsdos|linux|irix*|dec_osf|gnu*)
END
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if $perl_version >= 5.019004;
        5.013000 <= $perl_version;
    };
    conditional_patch "bitrig_bitrigcx", $perl_version_check, $BITRIG_CONDITION, $patch;
}

my $AIX_CONDITION = <<'END';
[[ $(uname -s) = AIX ]]
END
{
    my $patch = <<'END';
--- cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_AIX.pm
+++ cpan/ExtUtils-MakeMaker/lib/ExtUtils/MM_AIX.pm
@@ -50,7 +50,9 @@ sub xs_dlsyms_ext {
 
 sub xs_dlsyms_arg {
     my($self, $file) = @_;
-    return qq{-bE:${file}};
+    my $arg = qq{-bE:${file}};
+    $arg = '-Wl,'.$arg if $Config{lddlflags} =~ /-Wl,-bE:/;
+    return $arg;
 }
 
 sub init_others {
END
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return unless $perl_version > 5.027000;
        return unless $perl_version < 5.031001;
        1;
    };
    conditional_patch "mmaix_pm", $perl_version_check, $AIX_CONDITION, $patch;
}

