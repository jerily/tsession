ifndef PREFIX
    PREFIX  = /usr/local
endif

VERSION = 1.0.4
INSTALLDIR=${PREFIX}/lib/tsession${VERSION}

install:
	mkdir -p ${INSTALLDIR}
	cp pkgIndex.tcl ${INSTALLDIR}
	cp -R tcl ${INSTALLDIR}