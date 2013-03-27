%module pyz80
%{
    #include <stdio.h>
    #define SWIG_FILE_WITH_INIT
    #include "z80.h"

    static byte Z80MemoryRead(void *ctx, ushort address)
    {
        /* Use the Z80 context to find the memory read callback */
        Z80Context *context = (Z80Context *) ctx;

        /* if the callback is null or not callable return 0 */
        if (context->memReadCallback == NULL || !PyCallable_Check(context->memReadCallback)) {
            return 0;
        }

        PyObject *pyresult = \
            PyObject_CallFunction(context->memReadCallback, "ii", context->memParam, address);

        if (pyresult && PyInt_Check(pyresult)) {
            /* Return the result, converting from a python int */
            byte retval = (byte)PyInt_AsLong(pyresult);
            Py_DECREF(pyresult);
            return retval;
        } else {
            /* On error return 0 */
            return 0;
        }

    }
%}

%include "exception.i"

/* Convert from Python --> C */
%typemap(in) ushort {
    $1 = (ushort)PyInt_AsLong($input);
}

/* Convert from C --> Python */
%typemap(out) byte {
    $result = PyInt_FromLong((long)$1);
}

/* Check type for callback and make sure it's callable, else raise
 * an exception */
%typemap(check) PyObject* callback {
    if (!PyCallable_Check($1)) {
        SWIG_exception(SWIG_TypeError, "callback must be callable");
    }
}

%typemap(in) PyObject* {
    $1 = $input;
}

%typemap(in, numinputs=0) byte *result (byte temp) {
   $1 = &temp;
}

%typemap(out) int readMem {
    if ($1 == 0) {
        return NULL;
    }
}

%typemap(argout) byte *result {
    $result = PyInt_FromLong((long)*$1);
}

/** A Z80 execution context. */
typedef struct
{
    Z80Regs R1;     /**< Main register set (R) */
    Z80Regs R2;     /**< Alternate register set (R') */
    ushort  PC;     /**< Program counter */
    byte    R;      /**< Refresh */
    byte    I;
    byte    IFF1;   /**< Interrupt Flipflop 1 */
    byte    IFF2;   /**< Interrupt Flipflop 2 */
    byte    IM;     /**< Instruction mode */

    /* Add some extra attributes if it's SWIG */
    PyObject *memReadCallback;
    PyObject *memWriteCallback;
    PyObject *ioReadCallback;
    PyObject *ioWriteCallback;

} Z80Context;


%extend Z80Context {

    Z80Context() {
        Z80Context *z;
        z = (Z80Context *) malloc(sizeof(Z80Context));
        z->memRead = &Z80MemoryRead;
        z->memReadCallback = NULL;
        z->memWriteCallback = NULL;
        z->ioReadCallback = NULL;
        z->ioWriteCallback = NULL;
        z->memParam = 0;
        return z;
    }

    ~Z80Context() {
        return free($self);
    }

    /*
     * Wrappers for setting and getting the memory callbacks
     */

    /* Read memory */
    void setMemReadCallback(PyObject* callback) {

        /* Check to see if it is already set, an decref if it is */
        if ($self->memReadCallback != NULL) {
            Py_DECREF($self->memReadCallback);
        }

        Py_INCREF(callback);
        $self->memReadCallback = callback;
    }

    PyObject* getMemReadCallback() {
        return $self->memReadCallback;
    }

    int readMem(ushort address, byte *result) {
        /* if the callback is null or not callable return 0 */
        if ($self->memReadCallback == NULL || !PyCallable_Check($self->memReadCallback)) {
            return 0;
        }

        PyObject *pyresult = \
            PyObject_CallFunction($self->memReadCallback, "ii", $self->memParam, address);

        if (pyresult && PyInt_Check(pyresult)) {
            /* Return the result, converting from a python int */
            byte retval = (byte)PyInt_AsLong(pyresult);
            Py_DECREF(pyresult);
            *result = retval;
            return 1;
        } else {
            /* On error return 0 */
            return 0;
        }
    }

        /*
     * Dump the state of all the registers to stdout
     */
    void dump_z80_state(void) {
        printf("%04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x %04x\n",
                    $self->R1.wr.AF,
                    $self->R1.wr.BC,
                    $self->R1.wr.DE,
                    $self->R1.wr.HL,
                    $self->R2.wr.AF,
                    $self->R2.wr.BC,
                    $self->R2.wr.DE,
                    $self->R2.wr.HL,
                    $self->R1.wr.IX,
                    $self->R1.wr.IY,
                    $self->R1.wr.SP,
                    $self->PC);
        printf("%02x %02x %d %d %d %d %d\n",
                    $self->I,
                    $self->R,
                    $self->IFF1,
                    $self->IFF2,
                    $self->IM,
                    $self->halted,
                    $self->tstates);
    }

    /** Execute the next instruction. */
    void execute(void) { Z80Execute($self); }

    /** Execute enough instructions to use at least tstates cycles.
     * Returns the number of tstates actually executed.  Note: Resets
     * ctx->tstates.*/
    unsigned excute_tstates(unsigned tstates) { return Z80ExecuteTStates($self, tstates); }

    /** Decode the next instruction to be executed.
     * dump and decode can be NULL if such information is not needed
     *
     * @param dump A buffer which receives the hex dump
     * @param decode A buffer which receives the decoded instruction
     */
    void debug(char* dump, char* decode) { Z80Debug($self, dump, decode); }

    /** Resets the processor. */
    void reset() { Z80RESET($self); }

    /** Generates a hardware interrupt.
     * Some interrupt modes read a value from the data bus; this value must be provided in this function call, even
     * if the processor ignores that value in the current interrupt mode.
     *
     * @param value The value to read from the data bus
     */
    void interrupt(byte value) { Z80INT($self, value); }

    /** Generates a non-maskable interrupt. */
    void nmi() { Z80NMI($self); }


    %pythoncode %{
        __swig_getmethods__["memReadCallback"] = getMemReadCallback
        __swig_setmethods__["memReadCallback"] = setMemReadCallback
        if _newclass: memReadCallback = property(getMemReadCallback, setMemReadCallback)
    %}

}
