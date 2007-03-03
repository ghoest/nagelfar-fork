#----------------------------------------------------------------------
# Make file for Nagelfar
#----------------------------------------------------------------------
# $Revision$
#----------------------------------------------------------------------

VERSION = 118

# Path to the TclKits used for creating StarPacks.
TCLKIT = /home/peter/tclkit
TCLKIT_LINUX   = $(TCLKIT)/tclkit-linux-x86
TCLKIT_SOLARIS = $(TCLKIT)/tclkit-solaris-sparc
TCLKIT_WIN     = $(TCLKIT)/tclkit-win32.upx.exe

# Path to the libraries used
GRIFFIN = /home/peter/tclkit/griffin.vfs/lib/griffin
TKDND   = /home/peter/tkdnd/lib/tkdnd1.0
CTEXT   = /home/peter/src/ctext
TEXTSEARCH = /home/peter/src/textsearch

# Path to the interpreter used for generating the syntax database
TCLSHDB  = ~/tcl/install/bin/wish8.4
TCLSHDB2 = ~/tcl/install/bin/wish8.5
DB2NAME  = syntaxdb85.tcl
TCLSH85  = ~/tcl/install/bin/tclsh8.5

all: base

base: nagelfar.tcl setup misctest db

#----------------------------------------------------------------
# Setup symbolic links from the VFS to the real files
#----------------------------------------------------------------

nagelfar.vfs/lib/app-nagelfar/nagelfar.tcl:
	cd nagelfar.vfs/lib/app-nagelfar ; ln -s ../../../nagelfar.tcl
nagelfar.vfs/lib/app-nagelfar/syntaxdb.tcl:
	cd nagelfar.vfs/lib/app-nagelfar ; ln -s ../../../syntaxdb.tcl
nagelfar.vfs/lib/app-nagelfar/syntaxdb85.tcl:
	cd nagelfar.vfs/lib/app-nagelfar ; ln -s ../../../syntaxdb85.tcl
nagelfar.vfs/lib/app-nagelfar/doc:
	cd nagelfar.vfs/lib/app-nagelfar ; ln -s ../../../doc
nagelfar.vfs/lib/griffin:
	cd nagelfar.vfs/lib ; ln -s $(GRIFFIN) griffin
nagelfar.vfs/lib/tkdnd:
	cd nagelfar.vfs/lib ; ln -s $(TKDND) tkdnd
nagelfar.vfs/lib/ctext:
#	cd nagelfar.vfs/lib ; ln -s $(CTEXT) ctext
nagelfar.vfs/lib/textsearch:
	cd nagelfar.vfs/lib ; ln -s $(TEXTSEARCH) textsearch

links: nagelfar.vfs/lib/app-nagelfar/nagelfar.tcl \
	nagelfar.vfs/lib/app-nagelfar/syntaxdb.tcl \
	nagelfar.vfs/lib/app-nagelfar/syntaxdb85.tcl \
	nagelfar.vfs/lib/app-nagelfar/doc \
	nagelfar.vfs/lib/griffin \
	nagelfar.vfs/lib/tkdnd \
	nagelfar.vfs/lib/textsearch \
	nagelfar.vfs/lib/ctext

setup: links

#----------------------------------------------------------------
# Concatening source
#----------------------------------------------------------------

CATFILES = src/prologue.tcl src/nagelfar.tcl src/gui.tcl src/dbbrowser.tcl \
	src/registry.tcl src/preferences.tcl src/startup.tcl


nagelfar.tcl: $(CATFILES)
	cat $(CATFILES) > nagelfar.tcl
	@chmod 775 nagelfar.tcl

#----------------------------------------------------------------
# Testing
#----------------------------------------------------------------

spell:
	@cat doc/*.txt | ispell -d british -l | sort -u

# Create a common "header" file for all source files.
nagelfar_h.syntax: nagelfar.tcl nagelfar.syntax $(CATFILES)
	@echo Creating syntax header file...
	@./nagelfar.tcl -header nagelfar_h.syntax nagelfar.syntax $(CATFILES)

check: nagelfar.tcl nagelfar_h.syntax
	@./nagelfar.tcl -strictappend nagelfar_h.syntax $(CATFILES)

test: base
	@./tests/all.tcl $(TESTFLAGS)

test85: base
	@$(TCLSH85) ./tests/all.tcl $(TESTFLAGS)

#----------------------------------------------------------------
# Coverage
#----------------------------------------------------------------

# Source files for code coverage
SRCFILES = $(CATFILES)
IFILES   = $(SRCFILES:.tcl=.tcl_i)
LOGFILES = $(SRCFILES:.tcl=.tcl_log)
MFILES   = $(SRCFILES:.tcl=.tcl_m)

# Instrument source file for code coverage
%.tcl_i: %.tcl
	@./nagelfar.tcl -instrument $<

# Target to prepare for code coverage run. Makes sure log file is clear.
instrument: $(IFILES) nagelfar.tcl_i
	@rm -f $(LOGFILES)

# Top file for coverage run
nagelfar_dummy.tcl: $(IFILES)
	@rm -f nagelfar_dummy.tcl
	@touch nagelfar_dummy.tcl
	@echo "#!/usr/bin/env tclsh" >> nagelfar_dummy.tcl
	@for i in $(SRCFILES) ; do echo "source $$i" >> nagelfar_dummy.tcl ; done

# Top file for coverage run
nagelfar.tcl_i: nagelfar_dummy.tcl_i
	@cp -f nagelfar_dummy.tcl_i nagelfar.tcl_i
	@chmod 775 nagelfar.tcl_i

# Run tests to create log file.
testcover $(LOGFILES): nagelfar.tcl_i
	@./tests/all.tcl $(TESTFLAGS)
	@$(TCLSH85) ./tests/all.tcl -match expand-*

# Create markup file for better view of result
%.tcl_m: %.tcl_log 
	@./nagelfar.tcl -markup $*.tcl

# View code coverage result
icheck: $(MFILES)
	@for i in $(SRCFILES) ; do eskil -noparse $$i $${i}_m & done

# Remove code coverage files
clean:
	@rm -f $(LOGFILES) $(IFILES) $(MFILES) nagelfar.tcl_* nagelfar_dummy*

#----------------------------------------------------------------
# Generating test examples
#----------------------------------------------------------------

misctests/test.result: misctests/test.tcl nagelfar.tcl
	@cd misctests; ../nagelfar.tcl test.tcl > test.result

misctests/test.html: misctests/test.tcl misctests/htmlize.tcl \
		misctests/test.result
	@cd misctests; ./htmlize.tcl

misctest: misctests/test.result misctests/test.html

#----------------------------------------------------------------
# Generating database
#----------------------------------------------------------------

syntaxdb.tcl: syntaxbuild.tcl $(TCLSHDB)
	$(TCLSHDB) syntaxbuild.tcl syntaxdb.tcl

$(DB2NAME): syntaxbuild.tcl $(TCLSHDB2)
	$(TCLSHDB2) syntaxbuild.tcl $(DB2NAME)

db: syntaxdb.tcl $(DB2NAME)

#----------------------------------------------------------------
# Packaging/Releasing
#----------------------------------------------------------------

wrap: base
	sdx wrap nagelfar.kit

wrapexe: base
	@\rm -f nagelfar nagelfar.exe nagelfar.solaris
	sdx wrap nagelfar.linux   -runtime $(TCLKIT_LINUX)
	sdx wrap nagelfar.solaris -runtime $(TCLKIT_SOLARIS)
	sdx wrap nagelfar.exe     -runtime $(TCLKIT_WIN)

distrib: base
	@\rm -f nagelfar.tar.gz
	@tar --directory=..  --exclude CVS -zcvf nagelfar.tar.gz nagelfar/COPYING \
		nagelfar/README.txt nagelfar/syntaxbuild.tcl \
		nagelfar/syntaxdb.tcl nagelfar/syntaxdb85.tcl \
		nagelfar/nagelfar.syntax nagelfar/nagelfar.tcl \
		nagelfar/misctests/test.tcl nagelfar/misctests/test.syntax \
		nagelfar/doc

release: base distrib wrap wrapexe
	@cp nagelfar.tar.gz nagelfar`date +%Y%m%d`.tar.gz
	@mv nagelfar.tar.gz nagelfar$(VERSION).tar.gz
	@gzip nagelfar.linux
	@mv nagelfar.linux.gz nagelfar$(VERSION).linux.gz
	@zip nagelfar$(VERSION).win.zip nagelfar.exe
	@gzip nagelfar.solaris
	@mv nagelfar.solaris.gz nagelfar$(VERSION).solaris.gz
	@cp nagelfar.kit nagelfar`date +%Y%m%d`.kit
	@cp nagelfar.kit nagelfar$(VERSION).kit
