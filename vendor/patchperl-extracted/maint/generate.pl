#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/local/lib/perl5";
use Devel::PatchPerl;
use Devel::PatchPerl::Hints ();

use CPAN::Perl::Releases;
use File::Path 'make_path';
use File::Slurper qw(write_binary read_binary);
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
    _patch_pp_c_libc
    _patch_conf_gcc10
    _patch_useshrplib
    _patch_dynaloader_mac
    _patch_eumm_darwin
);

my @skip = qw(
    develpatchperlversion sysv patchlevel hints bitrig conf_solaris
    dynaloader_mac
    eumm_darwin
);

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
                warn "\e[1;32m---> found new patch: $name\e[m\n";
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
            if (/^\s+,NULL/ and $seen) {
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
    my $condition = read_binary 'maint/patch/condition.sysv';
    my $patch = read_binary 'maint/patch/sysv.patch';
    my $perl_version_check = sub {
        my $perl_version = shift;
        my @perl = (qr/^5\.8\.[0-8]$/, qr/^5\.9\.[0-5]$/);
        scalar grep { $perl_version =~ $_ } @perl;
    };
    conditional_patch "sysv", $perl_version_check, $condition, $patch;
}

my $SOLARIS_CONDITION = read_binary 'maint/patch/condition.solaris';
{
    my $patch = read_binary 'maint/patch/conf_solaris.patch';
    my $perl_version_check = sub {
        my $perl_version = shift;
        return version->parse($perl_version) < 5.018000;
        return 1;
    };
    conditional_patch "conf_solaris", $perl_version_check, $SOLARIS_CONDITION, $patch;
}

my $BITRIG_CONDITION = read_binary 'maint/patch/condition.bitrig';
{
    my $patch = read_binary 'maint/patch/bitrig_boogle.patch';
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if $perl_version >= 5.019004;
        return 1;
    };
    conditional_patch "bitrig_boogle", $perl_version_check, $BITRIG_CONDITION, $patch;
}
{
    my $patch = read_binary 'maint/patch/bitrig_bitrigm1.patch';
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if $perl_version >= 5.019004;
        $perl_version < 5.008009;
    };
    conditional_patch "bitrig_bitrigm1", $perl_version_check, $BITRIG_CONDITION, $patch;
}
{
    my $patch = read_binary 'maint/patch/bitrig_bitrigmx.patch';
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if $perl_version >= 5.019004;
        $perl_version >= 5.008009;
    };
    conditional_patch "bitrig_bitrigmx", $perl_version_check, $BITRIG_CONDITION, $patch;
}
{
    my $patch = read_binary 'maint/patch/bitrig_bitrigc3.patch';
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if $perl_version >= 5.019004;
        5.008001 <= $perl_version && $perl_version < 5.008007;
    };
    conditional_patch "bitrig_bitrigc3", $perl_version_check, $BITRIG_CONDITION, $patch;
}
{
    my $patch = read_binary 'maint/patch/bitrig_bitrigc2.patch';
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if $perl_version >= 5.019004;
        5.008007 <= $perl_version && $perl_version < 5.008009;
    };
    conditional_patch "bitrig_bitrigc2", $perl_version_check, $BITRIG_CONDITION, $patch;
}
{
    my $patch = read_binary 'maint/patch/bitrig_bitrigc1.patch';
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if $perl_version >= 5.019004;
        5.008009 <= $perl_version && $perl_version < 5.013000;
    };
    conditional_patch "bitrig_bitrigc1", $perl_version_check, $BITRIG_CONDITION, $patch;
}
{
    my $patch = read_binary 'maint/patch/bitrig_bitrigcx.patch';
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if $perl_version >= 5.019004;
        5.013000 <= $perl_version;
    };
    conditional_patch "bitrig_bitrigcx", $perl_version_check, $BITRIG_CONDITION, $patch;
}

my $AIX_CONDITION = read_binary 'maint/patch/condition.aix';
{
    my $patch = read_binary 'maint/patch/mmaix_pm.patch';
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return unless $perl_version > 5.027000;
        return unless $perl_version < 5.031001;
        1;
    };
    conditional_patch "mmaix_pm", $perl_version_check, $AIX_CONDITION, $patch;
}

my $DARWIN_CONDITION = read_binary 'maint/patch/condition.darwin';
{
    my $patch = read_binary 'maint/patch/dynaloader_mac.patch';
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if ($perl_version > 5.032000 && $perl_version < 5.033000 ) or $perl_version > 5.033005; # Reevaluate if v5.30.4 appears
        1;
    };
    conditional_patch "dynaloader_mac", $perl_version_check, $DARWIN_CONDITION, $patch;
}

for my $versions (
    ["5.8.1", "5.11.0"],
    ["5.11.0", "5.13.5"],
    ["5.13.5", "5.15.1"],
    ["5.15.1", undef],
) {
    my $lower_version = $versions->[0];
    my $upper_version = $versions->[1];
    my $patch = read_binary "maint/patch/eumm_darwin_$lower_version.patch";
    my $perl_version_check = sub {
        my $perl_version = version->parse(shift);
        return if ($perl_version > 5.032000 && $perl_version < 5.033000 ) or $perl_version > 5.033005; # Reevaluate if v5.30.4 appears
        version->parse($lower_version) <= $perl_version
            and ($upper_version ? $perl_version < version->parse($upper_version) : 1);
    };
    conditional_patch "eumm_darwin", $perl_version_check, $DARWIN_CONDITION, $patch;
}
