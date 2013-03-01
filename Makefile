SOURCES = z80.c
FLAGS = -fPIC -Wall -ansi -g
PYTHON_INCLUDE = -I/usr/include/python2.6

force: clean all

all: libz80.so libz80.py

libz80.so: z80.h $(OBJS)
	cd codegen && make opcodes
	gcc $(FLAGS) -shared -o libz80.so $(SOURCES)

libz80.py: libz80.so
	swig -python libz80.i
	gcc -c $(FLAGS) $(PYTHON_INCLUDE) z80.c libz80_wrap.c
	ld -shared libz80.so libz80_wrap.o -o _pyz80.so

install:
	install -m 666 libz80.so /usr/lib
	install -m 666 z80.h /usr/include

clean:
	rm -f *.o *.so core pyz80.{py,pyc} *_wrap.c
	cd codegen && make clean

realclean: clean
	rm -rf doc

doc:	*.h *.c
	doxygen

