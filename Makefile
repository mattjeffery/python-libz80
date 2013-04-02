SOURCES = z80.c
FLAGS = -fPIC -Wall -ansi -g

force: clean all

all: libz80.so libz80.py

libz80.so: z80.h $(OBJS)
	cd codegen && make opcodes
	gcc $(FLAGS) -shared -o libz80.so $(SOURCES)

libz80.py:
	python setup.py build

test: libz80.py
	nosetests -w tests

install: libz80.so
	install -m 666 libz80.so /usr/lib
	install -m 666 z80.h /usr/include
	python setup.py install

clean:
	rm -f *.o *.so core pyz80.py* *_wrap.c
	cd codegen && make clean

realclean: clean
	rm -rf doc

doc:	*.h *.c
	doxygen
