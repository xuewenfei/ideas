default: ideas
all: ideas haddock hlint sdist

#---------------------------------------------------------------------------------------
# Applications, directories

CABAL   = cabal
GHC     = ghc
GHCI    = ghci
HADDOCK = haddock
HLINT   = hlint
RM      = rm
GIT     = git

GHCWARN = -Wall -fwarn-tabs

SRCDIR     = src
OUTDIR     = out
DOCSDIR    = docs
HADDOCKDIR = $(DOCSDIR)/haddock

HS-SOURCES = $(wildcard $(SRCDIR)/*/*.hs $(SRCDIR)/*/*/*.hs $(SRCDIR)/*/*/*/*.hs $(SRCDIR)/*/*/*/*/*.hs)

#---------------------------------------------------------------------------------------
# GHC

ghci: revision
	$(GHCI) -i$(SRCDIR) -odir $(OUTDIR) -hidir $(OUTDIR) $(GHCWARN)

ideas: revision
	$(GHC) -i$(SRCDIR) -odir $(OUTDIR) -hidir $(OUTDIR) $(GHCWARN) $(HS-SOURCES) 2>&1 | tee $(DOCSDIR)/compile.txt

#---------------------------------------------------------------------------------------
# Version information

revision: $(SRCDIR)/Ideas/Main/Revision.hs

$(SRCDIR)/Ideas/Main/Revision.hs:
	$(GIT) pull || true
	# Updating $@
	@echo "-- Automatically generated by Makefile.  Do not change." > $@
	@echo "module Ideas.Main.Revision where" >> $@
	@echo "" >> $@
	@echo "ideasVersion :: String" >> $@
	@grep '^version' ideas.cabal | sed 's/version: *\(.*\)/ideasVersion = "\1"/' >> $@
	@echo "" >> $@
	$(GIT) log -1 --pretty=format:'ideasRevision :: String%nideasRevision = "%H"%n%nideasLastChanged :: String%nideasLastChanged = "%cd"%n' >> $@

.PHONY: $(SRCDIR)/Ideas/Main/Revision.hs

#---------------------------------------------------------------------------------------
# Documentation

haddock:
	$(HADDOCK) --html -o $(HADDOCKDIR) --prologue=$(DOCSDIR)/prologue --title="Ideas: feedback services for intelligent tutoring systems" $(HS-SOURCES)
	
hlint:
	$(HLINT) --report=$(DOCSDIR)/hlint.html $(HS-SOURCES)
	exit 0

#---------------------------------------------------------------------------------------
# Cabal targets

configure: revision
	$(CABAL) configure

build: revision
	$(CABAL) build

install: revision
	$(CABAL) install

sdist: configure
	$(CABAL) sdist

#---------------------------------------------------------------------------------------
# Cleaning up

clean:
	$(CABAL) clean
	$(RM) -rf out
	$(RM) -rf $(DOCSDIR)/hlint.html
	$(RM) -rf $(DOCSDIR)/compile.txt
	$(RM) -rf $(HADDOCKDIR)
	
#---------------------------------------------------------------------------------------
# Misc

nolicense:
	find src -name \*.hs -print0 | xargs --null grep -L "LICENSE"

layered:
	@grep -R import src/Ideas/Text | grep "Ideas.Common"    || true
	@grep -R import src/Ideas/Text | grep "Ideas.Encoding" || true
	@grep -R import src/Ideas/Text | grep "Ideas.Main"     || true
	@grep -R import src/Ideas/Text | grep "Ideas.Service" || true
	
	@grep -R import src/Ideas/Common | grep "Ideas.Text" || true
	@grep -R import src/Ideas/Common | grep "Ideas.Encoding" || true
	@grep -R import src/Ideas/Common | grep "Ideas.Main" || true
	@grep -R import src/Ideas/Common | grep "Ideas.Service" || true
	
	@grep -R import src/Ideas/Service | grep "Ideas.Text" || true
	@grep -R import src/Ideas/Service | grep "Ideas.Encoding" || true
	@grep -R import src/Ideas/Service | grep "Ideas.Main" || true
	
	@grep -R import src/Ideas/Encoding | grep "Ideas.Main" || true
	
	@grep -R import src/Ideas/Main | grep "Ideas.Text" || true
	@grep -R import src/Ideas/Main | grep "Ideas.Common" || true
	
noid:
	find src -name \*.hs -print0 | xargs --null grep -L '$$Id'
