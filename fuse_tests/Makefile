.DEFAULT: all

all: check check.py

check: tests.expected coretest
	./coretest fuse_files/tests.in >tests.actual
	diff -u tests.expected tests.actual

check.py: tests.expected
	./coretest.py fuse_files/tests.in >pytests.actual
	diff -u tests.expected pytests.actual

clean:
	rm -rf tests.expected tests.actual

tests.expected: fuse_files/tests.expected
	./generate_expected.sh $< $@

coretest: coretest.c
	gcc -Wall -ansi -g -o $@ $< ../libz80.so

