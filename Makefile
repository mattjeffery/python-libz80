SOURCES = z80.c
FLAGS = -fPIC -Wall -ansi -g
PYTHON_INCLUDE = -I/usr/include/python2.7

force: clean all

all: libz80.so libz80.py

libz80.so: z80.h $(OBJS)
	cd codegen && make opcodes
	gcc $(FLAGS) -shared -o libz80.so $(SOURCES)

libz80.py: swig
	gcc -g -c $(FLAGS) $(PYTHON_INCLUDE) $(SOURCES) libz80_wrap.c -DSWIG -DSWIG_PYTHON
	ld -shared z80.o libz80_wrap.o -o _pyz80.so

swig:
	swig -python libz80.i

test: libz80.py
	nosetests -w tests

install:
	install -m 666 libz80.so /usr/lib
	install -m 666 z80.h /usr/include

clean:
	rm -f *.o *.so core pyz80.py* *_wrap.c
	cd codegen && make clean

realclean: clean
	rm -rf doc

doc:	*.h *.c
	doxygen
