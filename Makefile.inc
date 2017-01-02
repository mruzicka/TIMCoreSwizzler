override BUILD_UTILS=BuildUtils

# define variable for comma
,:=,

# quote the argument so as to be safe to pass as a shell command line argument
shellquote="$(subst ",\",$(subst $$,\$$,$(subst `,\`,$(subst \,\\,$(1)))))"

# quote the argument so as to be a legal C string literal
cquote="$(subst ",\",$(subst \,\\,$(1)))"

# escape spaces & tabs in the argument so as to be treated by make as a single word
makeescape=$(shell python -c 'import $(BUILD_UTILS); $(BUILD_UTILS).makeEscape()' $(call shellquote,$(1)))


QUOTED.@=$(call shellquote,$@)
QUOTED.<=$(call shellquote,$<)
QUOTED.^=$(foreach p,$^,$(call shellquote,$p))

OUTPUT_OPTION=-o $(QUOTED.@)

%.o: %.m
	$(COMPILE.m) $(OUTPUT_OPTION) $(QUOTED.<)
