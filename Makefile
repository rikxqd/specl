CHMOD	= chmod
HELP2MAN= help2man
LDOC	= ldoc
LUA	= lua
MKDIR	= mkdir -p
SED	= sed
SPECL	= ./specl

VERSION	= 15.0.0

luadir	= lib/specl
SOURCES =				\
	$(luadir)/badargs.lua		\
	$(luadir)/color.lua		\
	$(luadir)/compat.lua		\
	$(luadir)/inprocess.lua		\
	$(luadir)/loader.lua		\
	$(luadir)/main.lua		\
	$(luadir)/matchers.lua		\
	$(luadir)/runner.lua		\
	$(luadir)/sandbox.lua		\
	$(luadir)/shell.lua		\
	$(luadir)/std.lua		\
	$(luadir)/util.lua		\
	$(luadir)/version.lua		\
	$(NOTHING_ELSE)

formatterdir = $(luadir)/formatter

dist_formatter_DATA =			\
	$(formatterdir)/progress.lua	\
	$(formatterdir)/report.lua	\
	$(formatterdir)/tap.lua		\
	$(NOTHING_ELSE)


all: doc $(luadir)/version.lua $(SPECL) doc/specl.1


$(luadir)/version.lua: $(luadir)/version.lua.in
	@$(SED) -e 's,@VERSION@,$(VERSION),' '$<' > '$@T';		\
	if cmp -s '$@' '$@T'; then					\
	    rm -f '$@T';						\
	else								\
	    echo "$(SED) -e 's,@VERSION@,$(VERSION),' '$<' > '$@T'";	\
	    rm -f '$@';							\
	    mv -f '$@T' '$@';						\
	    $(CHMOD) 444 '$@';						\
	fi

doc/specl.1: $(SPECL)
	$(HELP2MAN)			\
	  '--output=$@'			\
	  '--no-info'			\
	  '--name=Specl'		\
	  $(SPECL)

$(SPECL): $(SPECL).in Makefile
	rm -f '$@'
	$(SED) -e "s,@abs_top_srcdir@,`pwd`," '$<' > '$@'
	$(CHMOD) 555 '$@'

doc: doc/config.ld $(SOURCES)
	$(LDOC) -c doc/config.ld .

doc/config.ld: doc/config.ld.in
	$(SED) -e "s,@PACKAGE_VERSION@,$(VERSION)," '$<' > '$@'


CHECK_ENV = LUA=$(LUA)

check: $(SOURCES)
	LUA=$(LUA) $(SPECL) $(SPECL_OPTS) specs/*_spec.yaml


.FORCE:
