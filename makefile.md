# makefile

build system, but can be used for many other things.

by default, will build the first step defined in the file.

some make flags:
`-jN` flag can be used to build up to N steps in parallel. -j without N will set N to the number of processors (logical cores) in the machine.
`-lN` is similar to -j, but instead limits the number of jobs so that the total make load does not total more than N processors, so e.g. -j6 -l3 will use run up to 6 steps in parallel, but not utilize more than 300% single core load at once.

some tips:

`.ONESHELL` is a pseudo-target that runs all lines in a step within a single shell. without this set, every line in a step is run in a separate shell (though sequentially either way).
this can be useful e.g. for heredocs usage, where otherwise line-breaks would be required.

you can use line-breaks to continue commands beyond a single line, e.g.
`step:
	make -p \
	somefile && \
	touch somefile/text.txt
`

`.PHONY` pseudo-target can be used to indicate that a target does not produce output, e.g.
`.PHONY: clean`
this can be helpful to not re-run build steps that produce output (which otherwise would happen).

you can specify pre-requisit build steps, disregarding their modification time, using the pipe operator.
usually, a build step dependency like
`step2: step1 step0`
would re-run step2 if either step0 or step1 have been run (/changed) since the last invocation of step2. this is not always desired, e.g. when some command just requires a directory to exist, the command may not need to be re-run every time any content of the directory changes (which can modify the "last changed" timestamp on the directory, making it look like the directory itself has changed, even though that does not really make sense). using the pipe:
`mydir/sometext.txt: buildwhatever | mydir`
this will only run the mydir build step if mydir is missing, but disregard its timestamp. if the timestamp of buildwhatever has changed though, this step will be re-run (mydir will remain untouched).

using `$(MAKE)` inside a build step will run a sub-invocation of make and inherit all flags, so e.g. a complex build pipeline may build submodules with shared build flags so that the total build system will follow those flags, i.e. the top level and sublevels will not each invoke -jN steps, but they will in total invoke up to -jN steps.

heredocs tip:
using .ONESHELL enables heredocs use, i.e.
`echo << EOF
hello there
whatever
EOF
`
though there is more to this: something that looks like a command inside the heredoc will still be executed. the heredoc can be escaped by putting the EOF start marker into quotation marks
`bash -c << 'EOF'
echo $(HELLO)
EOF
`
this may be sometimes useful, and I have not done enough testing to figure out exactly what is executed in un-escaped heredocs, and why (just put the marks there to ensure proper escape).

heredocs can be used to create files with custom content, with little hassle:
`cat << 'EOF' > mytext.txt
once upon a time, there
was a happy, green frog
that sat on a leaf in a
pond. he sat there, ate
a fly every once in a
while, and croaked the
rest of the day. he was
a very happy frog.
EOF
`
the eof enclosed by quotation marks also ensures that the content will be handled as text.

small note on escaping:
in text, `$(MYVAR)` will be substituted for the value of MYVAR as set in the makefile. $MYVAR does not work, unlike bash.
to avoid substitution, e.g. when composing a bash command to be written into some file, $$ (double dollar sign) will be subsituted with a single dollar sign, so
`cat << 'EOF' > script.sh
$$(MYVAR) $(OTHERVAR)
EOF
`
will result in
`$ cat script.sh
$(MYVAR) somevalue
`

shell script syntax:
some shell script syntax is supported, notably pipes and stdout/stderr redirects, but complex statements like if etc. are not. those require escaping differently:
`( \
if [ -e $(MYVAR) "PETER"] ; then \
echo "HELLO PETER" \
fi \
)
`
(untested how this interacts with ONESHELL, but presumebly the line breaks could be left out then, just requiring the parenthesis to execute this code as shell script)
