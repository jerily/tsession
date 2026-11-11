ifndef PREFIX
    PREFIX  = /usr/local
endif

VERSION = 2.0.0
INSTALLDIR=${PREFIX}/lib/tsession${VERSION}

install:
	mkdir -p ${INSTALLDIR}
	cp pkgIndex.tcl readme.md LICENSE ${INSTALLDIR}
	cp -R tcl ${INSTALLDIR}
