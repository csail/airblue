#SUBDIRS = tools

#
# we have non-standard install sub-targets
#
.phony: install-indep install-arch doc install-exec-hook install-release install-bin install-package print-release-name

#
# Targets used when making a .deb file
#    WARNING: These targets assume that the $(DESTDIR) starts empty!!!
#
install-indep:

#
# Do install and install of package
#
install-arch: install


doc:
#	cd docs; make
	@echo "Done."

install-exec-hook: install-bin install-release
	@echo "Done."

install-release: all
	@echo "Done."

install-bin:


#
# This horrible sequence copies just the modules and other files needed to build 
# models to $(codedir)
# It also removes the .svn subdirectories in the installed tree.
#
install-package:
	@rm -rf  $(DESTDIR)$(codedir)
	$(mkinstalldirs)  $(DESTDIR)$(codedir)
	rsync -av --exclude .svn admin        $(DESTDIR)$(codedir)
	rsync -av --exclude .svn config       $(DESTDIR)$(codedir)
	rsync -av --exclude .svn experiments  $(DESTDIR)$(codedir)
	rsync -av --exclude .svn modules      $(DESTDIR)$(codedir)
	rsync -av --exclude .svn scripts      $(DESTDIR)$(codedir)
	rsync -av --exclude .svn tools        $(DESTDIR)$(codedir)

#
# we also need to fix up the distribution to contain the whole source tree
# minus the CVS directories
#
EXTRA_DIST = admin config include tools Makefile changes

dist-hook:
	make -C $(distdir) distclean
	find $(distdir) -name CVS -depth -exec rm -rf {} \;


#
# Utility target to print the release being built
#
print-release-name:
	@echo ${release}
