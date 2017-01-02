override MAKEFILE:=$(lastword $(MAKEFILE_LIST))

#### User Configurable Variables ###############################################

BUNDLENAME=Login Window Input Menu Update
BINNAME=$(SRCNAME)
DISPLAYNAME=$(BUNDLENAME)
BUNDLEID=net.mruza.LoginWindowInputMenuUpdate
BUNDLE_PRINCIPAL_CLASS=LWIMUObserverSubClass
WRAPPED_BUNDLE_PATH=/System/Library/LoginPlugins/DisplayServices.original.loginPlugin

BUNDLEDIR=$(DEFAULT_BUNDLEDIR)

#### End Of User Configurable Variables ########################################

# note the -emit-llvm flag allows for elimination of unused code (functions) during linking
CFLAGS+=-O3 -fpic -fobjc-arc -emit-llvm -DLWIMU_WRAPPED_BUNDLE_PATH=$(call shellquote,$(call cquote,$(WRAPPED_BUNDLE_PATH))) -DLWIMU_BUNDLE_PRINCIPAL_CLASS=$(call shellquote,$(call cquote,$(BUNDLE_PRINCIPAL_CLASS)))
LDLIBS=-bundle -framework Foundation -framework Carbon

override SRCNAME=LoginWindowInputMenuUpdate
override DEFAULT_BUNDLEDIR=installroot/$(BUNDLENAME)
override VARSFILE=.$(MAKEFILE).vars

BUNDLECONTENTSDIR=$(BUNDLEDIR)/Contents
BUNDLEEXEDIR=$(BUNDLECONTENTSDIR)/MacOS

INFOFILE=Info.plist
INFOFILETEMPLATE=$(INFOFILE).template

OBJFILE=$(SRCNAME).o
EXEFILE=$(BINNAME)

include Makefile.inc

# get the parent directory of the specified file/directory
parentdir=$(shell python -c 'import $(BUILD_UTILS); $(BUILD_UTILS).getParentDir()' $(call shellquote,$(1)))

M_BUNDLEDIR:=$(call makeescape,$(BUNDLEDIR))
M_BUNDLECONTENTSDIR:=$(call makeescape,$(BUNDLECONTENTSDIR))
M_BUNDLEEXEDIR:=$(call makeescape,$(BUNDLEEXEDIR))
M_WRAPPED_BUNDLE_PATH:=$(call makeescape,$(WRAPPED_BUNDLE_PATH))

M_INFOFILE:=$(call makeescape,$(INFOFILE))
M_INFOFILETEMPLATE:=$(call makeescape,$(INFOFILETEMPLATE))

M_OBJFILE:=$(call makeescape,$(OBJFILE))
M_EXEFILE:=$(call makeescape,$(EXEFILE))

VARS_CHANGED:=$(shell \
	python -c 'import $(BUILD_UTILS); $(BUILD_UTILS).checkAndSaveMakeVariables()' \
	$(call shellquote,$(VARSFILE)) $(call shellquote,$(MAKEFILE)) \
	$(foreach v,$(.VARIABLES),$(call shellquote,$v) $(call shellquote,$($v))) \
)

NEEDS_BACKUP:=$(shell \
	[ -w $(call shellquote,$(BUNDLEDIR)) ] \
	&& \
	[ ! -e $(call shellquote,$(WRAPPED_BUNDLE_PATH)) ] \
	&& \
	[ -w $(call shellquote,$(call parentdir,$(WRAPPED_BUNDLE_PATH))) ] \
	&& \
	echo 1 || : \
)


.PHONY: all backup install uninstall clean cleanall $(if $(VARS_CHANGED),$(MAKEFILE))


all: $(M_EXEFILE) |

$(M_OBJFILE): $(call makeescape,$(SRCNAME).m) $(MAKEFILE)

$(M_EXEFILE): $(M_OBJFILE)
	$(LINK.o) $(QUOTED.^) $(LDLIBS) $(OUTPUT_OPTION)

backup:
	mv $(call shellquote,$(BUNDLEDIR)) $(call shellquote,$(WRAPPED_BUNDLE_PATH))

# this will cause the Makefile to be re-read and the rules re-evaluated
# during which the make realizes the BUNDLEDIR is gone after the backup
# target was executed which results in re-execution of the directory
# creation order-only targets
# without this rule make would not notice the BUNDLEDIR is gone and the
# the directory creation order-only targets would not be re-execetued
Makefile.inc: $(if $(NEEDS_BACKUP),backup)

$(M_BUNDLEDIR):
	install -d -m 755 $(QUOTED.@)

$(M_BUNDLECONTENTSDIR): | $(M_BUNDLEDIR)
	install -d -m 755 $(QUOTED.@)

$(M_BUNDLEEXEDIR): | $(M_BUNDLECONTENTSDIR)
	install -d -m 755 $(QUOTED.@)

$(M_BUNDLECONTENTSDIR)/$(M_INFOFILE): $(M_INFOFILETEMPLATE) $(MAKEFILE) | $(M_BUNDLECONTENTSDIR)
	install -M -m 644 /dev/null $(QUOTED.@)
	python -c 'import $(BUILD_UTILS); $(BUILD_UTILS).processPList()' $(QUOTED.<) \
	CFBundleDisplayName $(call shellquote,$(call cquote,$(DISPLAYNAME))) \
	CFBundleExecutable  $(call shellquote,$(call cquote,$(EXEFILE))) \
	CFBundleIdentifier  $(call shellquote,$(call cquote,$(BUNDLEID))) \
	NSPrincipalClass    $(call shellquote,$(call cquote,$(BUNDLE_PRINCIPAL_CLASS))) \
	> $(QUOTED.@)

$(M_BUNDLEEXEDIR)/$(M_EXEFILE): $(M_EXEFILE) | $(M_BUNDLEEXEDIR)
	install -m 755 $(QUOTED.<) $(QUOTED.@)

install: $(M_BUNDLECONTENTSDIR)/$(M_INFOFILE) $(M_BUNDLEEXEDIR)/$(M_EXEFILE)

uninstall: $(if $(NEEDS_BACKUP),backup)
	-rm -rf $(call shellquote,$(BUNDLEDIR))

clean:
	-rm -f  $(call shellquote,$(OBJFILE))

cleanall: clean
	-rm -f  $(call shellquote,$(EXEFILE))
	-rm -rf $(call shellquote,$(call parentdir,$(DEFAULT_BUNDLEDIR)))
	-rm -f  $(call shellquote,$(BUILD_UTILS).pyc)
	-rm -f  $(call shellquote,$(VARSFILE))
