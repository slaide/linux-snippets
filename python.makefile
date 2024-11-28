#!/usr/bin/env make

# Define the Python version (pick from https://www.python.org/downloads/)
# tested with: 3.9.20, 3.10.14, 3.10.15, 3.11.10, 3.12.7, 3.13.0

PYTHON_VERSION?=3.13.0

LDFLAGS?=
CPPFLAGS?=
PKG_CONFIG_PATH?=

OS="$(shell uname)"
SCRIPT_DIR=$(shell pwd)

DL_CMD=curl -L -sS

PYTHON_VERSION_NOPATCH=$(shell echo $(PYTHON_VERSION) | cut -d'.' -f1,2)

PYTHON_VERSION_MAJOR=$(shell echo $(PYTHON_VERSION) | cut -d'.' -f1)
PYTHON_VERSION_MINOR=$(shell echo $(PYTHON_VERSION) | cut -d'.' -f2)
PYTHON_VERSION_PATCH=$(shell echo $(PYTHON_VERSION) | cut -d'.' -f3)
PYTHON_CONFIGURE_FLAGS=
ifeq ($(shell [ $(PYTHON_VERSION_MINOR) -ge 13 ] && echo 1), 1)
    PYTHON_CONFIGURE_FLAGS+= --with-platlibdir=lib
endif

PYTHON_INSTALL_DIR=$(SCRIPT_DIR)/python-$(PYTHON_VERSION)
PYTHON_SOURCE_DIR=$(PYTHON_INSTALL_DIR)-src
PYTHON_ARCHIVE_NAME=python-$(PYTHON_VERSION).tgz

OPENSSL_VERSION?=3.3.1
OPENSSL_INSTALL_DIR=$(SCRIPT_DIR)/openssl-$(OPENSSL_VERSION)
OPENSSL_SOURCE_DIR=$(OPENSSL_INSTALL_DIR)-src
OPENSSL_ARCHIVE_NAME=openssl-$(OPENSSL_VERSION).tar.gz

XZ_VERSION?=5.6.2
XZ_INSTALL_DIR=$(SCRIPT_DIR)/xz-$(XZ_VERSION)
XZ_SOURCE_DIR=$(XZ_INSTALL_DIR)-src
XZ_ARCHIVE_NAME=xz-$(XZ_VERSION).tar.gz

READLINE_VERSION?=8.1
READLINE_INSTALL_DIR=$(SCRIPT_DIR)/readline-$(READLINE_VERSION)
READLINE_SOURCE_DIR=$(READLINE_INSTALL_DIR)-src
READLINE_ARCHIVE_NAME=readline-$(READLINE_VERSION).tar.gz

TCL_VERSION?=8.6.13
TCL_VERSION_NOPATCH=$(shell echo $(TCL_VERSION) | cut -d'.' -f1,2)
TCL_INSTALL_DIR=$(SCRIPT_DIR)/tcl-$(TCL_VERSION)
TCL_SOURCE_DIR=$(TCL_INSTALL_DIR)-src
TCL_ARCHIVE_NAME=tcl-$(TCL_VERSION).tar.gz

TK_VERSION?=8.6.13
TK_VERSION_NOPATCH=$(shell echo $(TK_VERSION) | cut -d'.' -f1,2)
TK_INSTALL_DIR=$(SCRIPT_DIR)/tk-$(TK_VERSION)
TK_SOURCE_DIR=$(TK_INSTALL_DIR)-src
TK_ARCHIVE_NAME=tk-$(TK_VERSION).tar.gz

NCURSES_VERSION?=6.4
NCURSES_INSTALL_DIR=$(SCRIPT_DIR)/ncurses-$(NCURSES_VERSION)
NCURSES_SOURCE_DIR=$(NCURSES_INSTALL_DIR)-src
NCURSES_ARCHIVE_NAME=ncurses-$(NCURSES_VERSION).tar.gz

ICU_VERSION?=74.2
ICU_INSTALL_DIR=$(SCRIPT_DIR)/icu-$(ICU_VERSION)
ICU_SOURCE_DIR=$(ICU_INSTALL_DIR)-src
ICU_ARCHIVE_NAME=icu-$(ICU_VERSION).tgz

ALL_SOURCE_DIRS=$(ICU_SOURCE_DIR) $(READLINE_SOURCE_DIR) $(TCL_SOURCE_DIR) $(TK_SOURCE_DIR) $(NCURSES_SOURCE_DIR) $(XZ_SOURCE_DIR) $(OPENSSL_SOURCE_DIR)
ALL_ARCHIVES=$(ICU_ARCHIVE_NAME) $(READLINE_ARCHIVE_NAME) $(TCL_ARCHIVE_NAME) $(TK_ARCHIVE_NAME) $(NCURSES_ARCHIVE_NAME) $(XZ_ARCHIVE_NAME) $(OPENSSL_ARCHIVE_NAME) $(PYTHON_ARCHIVE_NAME)

ALL_DEP_INSTALL_DIRS=$(ICU_INSTALL_DIR) $(READLINE_INSTALL_DIR) $(TCL_INSTALL_DIR) $(TK_INSTALL_DIR) $(NCURSES_INSTALL_DIR) $(XZ_INSTALL_DIR) $(OPENSSL_INSTALL_DIR)

.PHONY:all
all: $(ALL_DEP_INSTALL_DIRS) $(PYTHON_INSTALL_DIR)

.PHONY:clean
clean:
	rm -rf $(ALL_DEP_INSTALL_DIRS) $(PYTHON_INSTALL_DIR) $(ALL_ARCHIVES) $(ALL_SOURCE_DIRS)

$(ICU_ARCHIVE_NAME):
	$(DL_CMD) -o $(ICU_ARCHIVE_NAME) "https://github.com/unicode-org/icu/releases/download/release-$(subst .,-,$(ICU_VERSION))/icu4c-$(subst .,_,$(ICU_VERSION))-src.tgz"
$(ICU_SOURCE_DIR):$(ICU_ARCHIVE_NAME)
	mkdir -p $(ICU_SOURCE_DIR)
	tar -xzf $(ICU_ARCHIVE_NAME) -C $(ICU_SOURCE_DIR) --strip-components=1
$(ICU_INSTALL_DIR):$(ICU_SOURCE_DIR)
	mkdir -p $(ICU_INSTALL_DIR)

	cd $(ICU_SOURCE_DIR)/source && \
	./configure --prefix=$(ICU_INSTALL_DIR) --enable-static --disable-shared && \
	$(MAKE) && \
	$(MAKE) install

$(READLINE_ARCHIVE_NAME):
	$(DL_CMD) -o $(READLINE_ARCHIVE_NAME) "https://ftp.gnu.org/gnu/readline/readline-$(READLINE_VERSION).tar.gz"
$(READLINE_SOURCE_DIR): $(READLINE_ARCHIVE_NAME)
	mkdir -p $(READLINE_SOURCE_DIR)
	tar -xzf $(READLINE_ARCHIVE_NAME) -C $(READLINE_SOURCE_DIR) --strip-components=1
$(READLINE_INSTALL_DIR): $(READLINE_SOURCE_DIR)
	mkdir -p $(READLINE_INSTALL_DIR)

	cd $(READLINE_SOURCE_DIR) && \
	./configure --prefix=$(READLINE_INSTALL_DIR) && \
	$(MAKE) && \
	$(MAKE) install

$(TCL_ARCHIVE_NAME):
	$(DL_CMD) -o $(TCL_ARCHIVE_NAME) "https://prdownloads.sourceforge.net/tcl/tcl$(TCL_VERSION)-src.tar.gz"
$(TCL_SOURCE_DIR):$(TCL_ARCHIVE_NAME)
	mkdir -p $(TCL_SOURCE_DIR)
	tar -xzf $(TCL_ARCHIVE_NAME) -C $(TCL_SOURCE_DIR) --strip-components=1
$(TCL_INSTALL_DIR):$(TCL_SOURCE_DIR)
	mkdir -p $(TCL_INSTALL_DIR)

	cd $(TCL_SOURCE_DIR)/unix && \
	./configure --prefix=$(TCL_INSTALL_DIR) && \
	$(MAKE) && \
	$(MAKE) install

$(TK_ARCHIVE_NAME):
	$(DL_CMD) -o $(TK_ARCHIVE_NAME) "https://prdownloads.sourceforge.net/tcl/tk$(TK_VERSION)-src.tar.gz"
$(TK_SOURCE_DIR):$(TK_ARCHIVE_NAME)
	mkdir -p $(TK_SOURCE_DIR)
	tar -xzf $(TK_ARCHIVE_NAME) -C $(TK_SOURCE_DIR) --strip-components=1
$(TK_INSTALL_DIR):$(TCL_INSTALL_DIR) $(TK_SOURCE_DIR)
	mkdir -p $(TK_INSTALL_DIR)

	( \
	if [ $(OS) = "DDarwin" ]; then \
		cd $(TK_SOURCE_DIR)/macosx && \
		CFLAGS="-I$(TCL_INSTALL_DIR)/include" ./configure --prefix="$(TK_INSTALL_DIR)" --with-tcl="$(TCL_INSTALL_DIR)/lib" --enable-aqua && \
		$(MAKE) && \
		$(MAKE) install; \
	else \
		cd $(TK_SOURCE_DIR)/unix && \
		CFLAGS="-I$(TCL_INSTALL_DIR)/include" ./configure --prefix="$(TK_INSTALL_DIR)" --with-tcl="$(TCL_INSTALL_DIR)/lib" --enable-aqua && \
		$(MAKE) && \
		$(MAKE) install; \
	fi \
	)

$(NCURSES_ARCHIVE_NAME):
	$(DL_CMD) -o $(NCURSES_ARCHIVE_NAME) "https://ftp.gnu.org/gnu/ncurses/ncurses-$(NCURSES_VERSION).tar.gz"
$(NCURSES_SOURCE_DIR):$(NCURSES_ARCHIVE_NAME)
	mkdir -p $(NCURSES_SOURCE_DIR)
	tar -xzf $(NCURSES_ARCHIVE_NAME) -C $(NCURSES_SOURCE_DIR) --strip-components=1
$(NCURSES_INSTALL_DIR):$(NCURSES_SOURCE_DIR)
	mkdir -p $(NCURSES_INSTALL_DIR)

	cd $(NCURSES_SOURCE_DIR) && \
	./configure --prefix=$(NCURSES_INSTALL_DIR) --with-shared --without-normal --without-debug --with-termlib --enable-widec && \
	$(MAKE) && \
	$(MAKE) install

	# no -lpanelw -> causes terminal misconfiguration in python configure

	( \
	if [ ! -e $(NCURSES_INSTALL_DIR)/lib/pkgconfig ]; then \
		mkdir -p $(NCURSES_INSTALL_DIR)/lib/pkgconfig; \
		echo 'prefix=$(NCURSES_INSTALL_DIR)\n\
exec_prefix=$${prefix}\n\
libdir=$${exec_prefix}/lib\n\
includedir=$${prefix}/include\n\
\n\
Name: ncurses\n\
Description: ncurses library\n\
Version: $(NCURSES_VERSION)\n\
Libs: -L$${libdir} -lncursesw -ltinfow \n\
Cflags: -I$${includedir}\n\
' > $(NCURSES_INSTALL_DIR)/lib/pkgconfig/ncurses.pc; \
		echo 'prefix=$(NCURSES_INSTALL_DIR)\n\
exec_prefix=$${prefix}\n\
libdir=$${exec_prefix}/lib\n\
includedir=$${prefix}/include\n\
\n\
Name: termcap\n\
Description: termcap library\n\
Version: $(NCURSES_VERSION)\n\
Libs: -L$${libdir} -lncursesw -ltinfow \n\
Cflags: -I$${includedir}\n\
' > $(NCURSES_INSTALL_DIR)/lib/pkgconfig/termcap.pc; \
	fi \
	)

$(OPENSSL_ARCHIVE_NAME):
	$(DL_CMD) -o $(OPENSSL_ARCHIVE_NAME) "https://www.openssl.org/source/openssl-$(OPENSSL_VERSION).tar.gz"
$(OPENSSL_SOURCE_DIR):$(OPENSSL_ARCHIVE_NAME)
	mkdir -p $(OPENSSL_SOURCE_DIR)
	tar -xzf $(OPENSSL_ARCHIVE_NAME) -C $(OPENSSL_SOURCE_DIR) --strip-components=1
$(OPENSSL_INSTALL_DIR):$(OPENSSL_SOURCE_DIR)
	mkdir -p $(OPENSSL_INSTALL_DIR) 

	# must be shared
	cd $(OPENSSL_SOURCE_DIR) && \
	./config --prefix=$(OPENSSL_INSTALL_DIR) --openssldir=$(OPENSSL_INSTALL_DIR)/ssl -shared -fPIC zlib && \
	$(MAKE) depend && \
	$(MAKE) && \
	$(MAKE) install_sw

$(XZ_ARCHIVE_NAME):
	$(DL_CMD) -o $(XZ_ARCHIVE_NAME) "https://github.com/tukaani-project/xz/releases/download/v$(XZ_VERSION)/xz-$(XZ_VERSION).tar.gz"
$(XZ_INSTALL_DIR):$(XZ_ARCHIVE_NAME)
	# download and compile xz to provide lzma support for python
	
	mkdir -p $(XZ_INSTALL_DIR) $(XZ_SOURCE_DIR)
	tar -xzf $(XZ_ARCHIVE_NAME) -C $(XZ_SOURCE_DIR) --strip-components=1

	cd $(XZ_SOURCE_DIR) && \
	./configure --prefix=$(XZ_INSTALL_DIR) && \
	$(MAKE) && \
	$(MAKE) install

$(PYTHON_ARCHIVE_NAME):
	$(DL_CMD) -o $(PYTHON_ARCHIVE_NAME) "https://www.python.org/ftp/python/$(PYTHON_VERSION)/Python-$(PYTHON_VERSION).tgz"
$(PYTHON_SOURCE_DIR):$(PYTHON_ARCHIVE_NAME)
	mkdir -p $(PYTHON_SOURCE_DIR)
	tar -xzf $(PYTHON_ARCHIVE_NAME) -C $(PYTHON_SOURCE_DIR) --strip-components=1
	
	# remove tests, which are unused
	cd $(PYTHON_SOURCE_DIR) && rm -rf Lib/test
$(PYTHON_INSTALL_DIR):$(PYTHON_SOURCE_DIR) $(ALL_DEP_INSTALL_DIRS)
	mkdir -p $(PYTHON_INSTALL_DIR)

	# Configure and make
	# + enable ssl support (required by pip for pypi packages) - this requires openssl to be installed on the system!
	# + tcl/k
	# + readline
	# + xz/liblzma
	# + also apply several optimizations to improve runtime performance (no --enable-optimizations flag \
	# because pgo generates wrong raw profile data, error: "version=8 instead of expected 9" ?!)

	# -j1 altinstall -> avoid a race condition with duplicate mkdir

	bash -c ' \
export PKG_CONFIG_PATH=$(PKG_CONFIG_PATH):$(OPENSSL_INSTALL_DIR)/lib/pkgconfig:$(OPENSSL_INSTALL_DIR)/lib64/pkgconfig:\
$(XZ_INSTALL_DIR)/lib/pkgconfig:$(READLINE_INSTALL_DIR)/lib/pkgconfig:$(TCL_INSTALL_DIR)/lib/pkgconfig:\
$(TK_INSTALL_DIR)/lib/pkgconfig:$(NCURSES_INSTALL_DIR)/lib/pkgconfig:$(ICU_INSTALL_DIR)/lib/pkgconfig; \
export LDFLAGS=" -Wl,-rpath,$(OPENSSL_INSTALL_DIR)/lib -Wl,-rpath,$(OPENSSL_INSTALL_DIR)/lib64 $$(pkg-config --libs   ncurses termcap openssl liblzma readline tcl tk icu-i18n) $(LDFLAGS) " ; \
export CPPFLAGS=" $$(pkg-config --cflags ncurses termcap openssl liblzma readline tcl tk icu-i18n) $(CPPFLAGS) " ; \
cd $(PYTHON_SOURCE_DIR) && \
./configure \
	--with-openssl="$(OPENSSL_INSTALL_DIR)" \
	--with-readline=readline --with-readline-dir="$(READLINE_INSTALL_DIR)" \
	--with-tcltk-includes="-I$(TCL_INSTALL_DIR)/include -I$(TK_INSTALL_DIR)/include" \
	--with-tcltk-libs="-L$(TCL_INSTALL_DIR)/lib -ltcl$(TCL_VERSION_NOPATCH) -L$(TK_INSTALL_DIR)/lib -ltk$(TK_VERSION_NOPATCH)" \
	--with-icu="$(ICU_INSTALL_DIR)" \
	--prefix="$(PYTHON_INSTALL_DIR)" \
	--with-lto --with-computed-gotos \
	--with-ensurepip $(PYTHON_CONFIGURE_FLAGS) && \
$(MAKE) && \
$(MAKE) -j1 altinstall'

	python3 -c "s='''#!/usr/bin/env bash \n\
export PYTHONPATH=$(PYTHON_INSTALL_DIR)/lib/python$(PYTHON_VERSION_NOPATCH) \n\
export PYTHONHOME=$(PYTHON_INSTALL_DIR) \n\
$(PYTHON_INSTALL_DIR)/bin/python$(PYTHON_VERSION_NOPATCH) $$'''+'''@'''; f=open('$(PYTHON_INSTALL_DIR)/bin/python3', 'x'); f.write(s); f.close()"

	bash $(PYTHON_INSTALL_DIR)/bin/python3 -m ensurepip
	bash $(PYTHON_INSTALL_DIR)/bin/python3 -m pip install --upgrade pip
