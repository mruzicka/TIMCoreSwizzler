override MAKEFILE:=$(lastword $(MAKEFILE_LIST))

#### User Configurable Variables ###############################################

BUNDLENAME=Login Window Input Menu Update
BINNAME=$(SRCNAME)
DISPLAYNAME=$(BUNDLENAME)
BUNDLEID=net.mruza.LoginWindowInputMenuUpdate
WRAPPED_BUNDLE_PATH=/Library/LoginPlugins/DisplayServices.loginPlugin

BUNDLEDIR=$(DEFAULT_BUNDLEDIR)

#### End Of User Configurable Variables ########################################

# note the -emit-llvm flag allows for elimination of unused code (functions) during linking
CFLAGS+=-O3 -fpic -fobjc-arc -emit-llvm -DLWIMU_WRAPPED_BUNDLE_PATH=$(call shellquote,$(call cquote,$(WRAPPED_BUNDLE_PATH)))
LDLIBS=-bundle -framework Foundation -framework Carbon

override SRCNAME=LoginWindowInputMenuUpdate
override DEFAULT_BUNDLEDIR=installroot/$(BUNDLENAME).bundle
override VARSFILE=.$(MAKEFILE).vars

BUNDLECONTENTSDIR=$(BUNDLEDIR)/Contents
BUNDLEEXEDIR=$(BUNDLECONTENTSDIR)/MacOS

WRAPPED_BUNDLE_PARENTDIR=$(call parentdir,$(WRAPPED_BUNDLE_PATH))

INFOFILE=Info.plist
INFOFILETEMPLATE=$(INFOFILE).template

OBJFILE=$(SRCNAME).o
EXEFILE=$(BINNAME)

include Makefile.inc

# get the parent directory of the specified file/directory
parentdir=$(shell python -c 'import $(BUILD_UTILS); $(BUILD_UTILS).getParentDir()' $(call shellquote,$(1)))
existing_parentdir=$(shell python -c 'import $(BUILD_UTILS); $(BUILD_UTILS).getExistingParentDir()' $(call shellquote,$(1)))

M_BUNDLEDIR:=$(call makeescape,$(BUNDLEDIR))
M_BUNDLECONTENTSDIR:=$(call makeescape,$(BUNDLECONTENTSDIR))
M_BUNDLEEXEDIR:=$(call makeescape,$(BUNDLEEXEDIR))
M_WRAPPED_BUNDLE_PATH:=$(call makeescape,$(WRAPPED_BUNDLE_PATH))
M_WRAPPED_BUNDLE_PARENTDIR:=$(call makeescape,$(WRAPPED_BUNDLE_PARENTDIR))

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
	[ -w $(call shellquote,$(call existing_parentdir,$(WRAPPED_BUNDLE_PATH))) ] \
	&& \
	echo 1 || : \
)

# we use $| to separate order-only dependencies in certain rules;
# this gives us the opportunity to change the order-only dependencies
# into normal dependencies by setting the $| to an empty string; and
# that's exactly what we take advantage of if backup is needed
|:=$(if $(NEEDS_BACKUP),,|)


.PHONY: all backup install uninstall clean cleanall $(if $(VARS_CHANGED),$(MAKEFILE))


all: $(M_EXEFILE) |

$(M_OBJFILE): $(call makeescape,$(SRCNAME).m) $(MAKEFILE)

$(M_EXEFILE): $(M_OBJFILE)
	$(LINK.o) $(QUOTED.^) $(LDLIBS) $(OUTPUT_OPTION)

$(M_BUNDLEDIR): $(if $(NEEDS_BACKUP),backup)
	install -d -m 755 $(QUOTED.@)

$(M_BUNDLECONTENTSDIR): $| $(M_BUNDLEDIR)
	install -d -m 755 $(QUOTED.@)

$(M_BUNDLEEXEDIR): $| $(M_BUNDLECONTENTSDIR)
	install -d -m 755 $(QUOTED.@)

$(M_BUNDLECONTENTSDIR)/$(M_INFOFILE): $(M_INFOFILETEMPLATE) $(MAKEFILE) $| $(M_BUNDLECONTENTSDIR)
	install -M -m 644 /dev/null $(QUOTED.@)
	python -c 'import $(BUILD_UTILS); $(BUILD_UTILS).processPLists(2)' \
	$(QUOTED.<) $(call shellquote,$(WRAPPED_BUNDLE_PATH)/Contents/Info.plist) \
	CFBundleDisplayName $(call shellquote,$(call cquote,$(DISPLAYNAME))) \
	CFBundleExecutable  $(call shellquote,$(call cquote,$(EXEFILE))) \
	CFBundleIdentifier  $(call shellquote,$(call cquote,$(BUNDLEID))) \
	NSPrincipalClass    $(call shellquote,properties[1].get("NSPrincipalClass", None)) \
	> $(QUOTED.@)

$(M_BUNDLEEXEDIR)/$(M_EXEFILE): $(M_EXEFILE) $| $(M_BUNDLEEXEDIR)
	install -m 755 $(QUOTED.<) $(QUOTED.@)

$(M_WRAPPED_BUNDLE_PARENTDIR):
	$(if $(NEEDS_BACKUP),install -d $(QUOTED.@))

$(M_WRAPPED_BUNDLE_PATH): | $(M_WRAPPED_BUNDLE_PARENTDIR)
	$(if $(NEEDS_BACKUP),mv $(call shellquote,$(BUNDLEDIR)) $(QUOTED.@))

backup: $(M_WRAPPED_BUNDLE_PATH)

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
