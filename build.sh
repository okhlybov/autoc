#

yardoc

(
	cd test
	make
	for f in *_auto.[ch]; do
		awk NF $f > $f~
		astyle -A14 < $f~ > $f
		rm $f~
	done
)

gem build autoc.gemspec

#