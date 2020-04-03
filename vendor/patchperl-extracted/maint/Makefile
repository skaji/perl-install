default:
	rm -rf local
	cpm install Devel::PatchPerl CPAN::Perl::Releases
	perl -i -pe 's/^my \@patch =/our \@patch =/' local/lib/perl5/Devel/PatchPerl.pm
	perl generate.pl

archive:
	cd .. && git archive HEAD --prefix=patchperl-extracted/ --output=patchperl-extracted.tar.gz
