ifndef PREFIX
    PREFIX  = /usr/local
endif

VERSION = 2.0.3
INSTALLDIR=${PREFIX}/lib/tsession${VERSION}

install:
	mkdir -p ${INSTALLDIR}
	cp pkgIndex.tcl readme.md LICENSE ${INSTALLDIR}
	cp -R tcl sql ${INSTALLDIR}
