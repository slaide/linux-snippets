#!/bin/bash

START_WD=$(pwd)

# Define the Python version (pick from https://www.python.org/downloads/)
PYTHON_VERSION="3.13.0"
PYTHON_VERSION_NOPATCH=$(echo $PYTHON_VERSION | cut -d'.' -f1,2)

# Define the installation directories
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd $SCRIPT_DIR

PYTHON_INSTALL_DIR="$SCRIPT_DIR/python-$PYTHON_VERSION"
PYTHON_SOURCE_DIR="$SCRIPT_DIR/python-src"
OPENSSL_INSTALL_DIR="$SCRIPT_DIR/openssl"
OPENSSL_SOURCE_DIR="$SCRIPT_DIR/openssl-src"
XZ_INSTALL_DIR="$SCRIPT_DIR/xz"
XZ_SOURCE_DIR="$SCRIPT_DIR/xz-src"
READLINE_INSTALL_DIR="$SCRIPT_DIR/readline"
READLINE_SOURCE_DIR="$SCRIPT_DIR/readline-src"
TCL_INSTALL_DIR="$SCRIPT_DIR/tcl"
TCL_SOURCE_DIR="$SCRIPT_DIR/tcl-src"
TK_INSTALL_DIR="$SCRIPT_DIR/tk"
TK_SOURCE_DIR="$SCRIPT_DIR/tk-src"
NCURSES_INSTALL_DIR="$SCRIPT_DIR/ncurses"
NCURSES_SOURCE_DIR="$SCRIPT_DIR/ncurses-src"

# when compiling a new python version, this block does not need to be re-run

if [ ! -e $TCL_INSTALL_DIR ] ; then
    echo "Downloading and installing Tcl"
    curl -L -o tcl.tar.gz https://prdownloads.sourceforge.net/tcl/tcl8.6.13-src.tar.gz
    mkdir -p $TCL_INSTALL_DIR $TCL_SOURCE_DIR
    tar -xzf tcl.tar.gz -C $TCL_SOURCE_DIR --strip-components=1
    cd $TCL_SOURCE_DIR/unix
    ./configure --prefix=$TCL_INSTALL_DIR
    make -j
    make install
    cd $SCRIPT_DIR
    rm -rf $TCL_SOURCE_DIR tcl.tar.gz
    echo "Finished installing Tcl"
fi

if [ ! -e $TK_INSTALL_DIR ] ; then
    echo "Downloading and installing Tk"
    curl -L -o tk.tar.gz https://prdownloads.sourceforge.net/tcl/tk8.6.13-src.tar.gz
    mkdir -p $TK_INSTALL_DIR $TK_SOURCE_DIR
    tar -xzf tk.tar.gz -C $TK_SOURCE_DIR --strip-components=1
    cd $TK_SOURCE_DIR/unix

    export CFLAGS="-I$TCL_INSTALL_DIR/include"
    
    ./configure --prefix=$TK_INSTALL_DIR --with-tcl=$TCL_INSTALL_DIR/lib
    make -j
    make install

    unset CFLAGS
    
    cd $SCRIPT_DIR
    rm -rf $TK_SOURCE_DIR tk.tar.gz
    echo "Finished installing Tk"
fi

if [ ! -e $NCURSES_INSTALL_DIR ] ; then
    echo "Downloading and installing ncurses"
    curl -L -o ncurses.tar.gz https://ftp.gnu.org/gnu/ncurses/ncurses-6.4.tar.gz
    mkdir -p $NCURSES_INSTALL_DIR $NCURSES_SOURCE_DIR
    tar -xzf ncurses.tar.gz -C $NCURSES_SOURCE_DIR --strip-components=1
    cd $NCURSES_SOURCE_DIR
    ./configure --prefix=$NCURSES_INSTALL_DIR --with-shared --without-debug --enable-widec
    make -j
    make install
    cd $SCRIPT_DIR
    rm -rf $NCURSES_SOURCE_DIR ncurses.tar.gz
    echo "Finished installing ncurses"
fi
    
if [ ! -e $OPENSSL_INSTALL_DIR ] ; then
    # download and compile openssl for use by python
    echo downloading openssl
    curl -L -o openssl.tar.gz https://www.openssl.org/source/openssl-3.3.1.tar.gz
    mkdir -p $OPENSSL_INSTALL_DIR $OPENSSL_SOURCE_DIR
    tar -xzf openssl.tar.gz -C $OPENSSL_SOURCE_DIR --strip-components=1
    cd $OPENSSL_SOURCE_DIR
    ./config --prefix=$OPENSSL_INSTALL_DIR --openssldir=$OPENSSL_INSTALL_DIR/ssl shared zlib
    make -j1 depend
    make -j
    # make -j test
    make -j install_sw

    # remove openssl source code files after installation
    cd $SCRIPT_DIR
    rm -rf $OPENSSL_SOURCE_DIR $SCRIPT_DIR/openssl.tar.gz
	echo finished installing openssl
fi

if [ ! -e $XZ_INSTALL_DIR ] ; then
    # download and compile xz to provide lzma support for python
    echo downloading xz
    curl -L -o xz.tar.gz https://github.com/tukaani-project/xz/releases/download/v5.6.2/xz-5.6.2.tar.gz
    mkdir -p $XZ_INSTALL_DIR $XZ_SOURCE_DIR
    tar -xzf xz.tar.gz -C $XZ_SOURCE_DIR --strip-components=1
    cd $XZ_SOURCE_DIR
    ./configure --prefix=$XZ_INSTALL_DIR
    make -j
    make -j install

    # remove xz source code files after installation
    cd $SCRIPT_DIR
    rm -rf $XZ_SOURCE_DIR $SCRIPT_DIR/xz.tar.gz
	echo finished installing xz
fi

# Update environment variables to include xz and openssl
export PATH=$XZ_INSTALL_DIR/bin:$OPENSSL_INSTALL_DIR/bin:$READLINE_INSTALL_DIR/bin:$PATH
export LD_LIBRARY_PATH=$XZ_INSTALL_DIR/lib:$OPENSSL_INSTALL_DIR/lib:$READLINE_INSTALL_DIR/lib:$LD_LIBRARY_PATH
export C_INCLUDE_PATH=$XZ_INSTALL_DIR/include:$OPENSSL_INSTALL_DIR/include:$READLINE_INSTALL_DIR/include:$C_INCLUDE_PATH
export LIBRARY_PATH=$XZ_INSTALL_DIR/lib:$OPENSSL_INSTALL_DIR/lib:$READLINE_INSTALL_DIR/lib:$LIBRARY_PATH

# add openssl/lib64 and openssl/lib to linker args. which of the two is generated by openssl is platform dependent
export LDFLAGS="$LDFLAGS -L$READLINE_INSTALL_DIR/lib -L$OPENSSL_INSTALL_DIR/lib64 -L$OPENSSL_INSTALL_DIR/lib -Wl,-rpath=$OPENSSL_INSTALL_DIR/lib64 -Wl,-rpath=$OPENSSL_INSTALL_DIR/lib"

# Download and compile python
if [ ! -e $PYTHON_INSTALL_DIR ] ; then
	if [ ! -e "python.tgz" ]; then
		PYTHON_URL="https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz"
		curl -o python.tgz $PYTHON_URL
	fi
	
	mkdir -p $PYTHON_INSTALL_DIR $PYTHON_SOURCE_DIR
	tar -xzf python.tgz -C $PYTHON_SOURCE_DIR --strip-components=1
	cd $PYTHON_SOURCE_DIR
	# Configure and make
	# + enable ssl support (required by pip for pypi packages) - this requires openssl to be installed on the system!
	# + also apply several optimizations to improve runtime performance (no --enable-optimizations flag \
	# because pgo generates wrong raw profile data, version=8 instead of expected 9?!)
	./configure \
		--with-openssl=$OPENSSL_INSTALL_DIR \
		--with-readline --with-readline-dir=$READLINE_INSTALL_DIR \
		--with-tcltk-includes="-I$TCL_INSTALL_DIR/include -I$TK_INSTALL_DIR/include" \
		--with-tcltk-libs="-L$TCL_INSTALL_DIR/lib -ltcl8.6 -L$TK_INSTALL_DIR/lib -ltk8.6" \
		--with-ncurses="$NCURSES_INSTALL_DIR" \
		--prefix=$PYTHON_INSTALL_DIR \
		--with-lto --with-computed-gotos \
		--with-ensurepip 
	
	# copy configuration file, e.g. for debugging
	if true; then
		cp config.log ..
	fi
	
	make -j
	make -j altinstall

	# remove python source code files after installation
	cd $SCRIPT_DIR
	rm -rf $PYTHON_SOURCE_DIR $SCRIPT_DIR/python.tgz

	# create link to be able to use python3 instead of python3.10
	cd $PYTHON_INSTALL_DIR/bin
	ln -s python$PYTHON_VERSION_NOPATCH python3

	echo "Python $PYTHON_VERSION installed successfully into $PYTHON_INSTALL_DIR"
fi

# install package dependencies
cd $SCRIPT_DIR
python-3*/bin/python3 -m pip install --upgrade pip
