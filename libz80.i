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

    static void Z80MemoryWrite(void *ctx, ushort address, byte val)
    {
        /* Use the Z80 context to find the io read callback */
        Z80Context *context = (Z80Context *) ctx;

        /* if the callback is null or not callable return 0 */
        if (context->memWriteCallback != NULL && PyCallable_Check(context->memWriteCallback)) {
            PyObject *pyresult = \
                PyObject_CallFunction(context->memWriteCallback, "iii", context->memParam, address, val);

            if (pyresult) {
                Py_DECREF(pyresult);
            }
        }
    }

    static byte Z80IoRead(void *ctx, ushort address)
    {
        /* Use the Z80 context to find the io read callback */
        Z80Context *context = (Z80Context *) ctx;

        /* if the callback is null or not callable return 0 */
        if (context->ioReadCallback == NULL || !PyCallable_Check(context->ioReadCallback)) {
            return 0;
        }

        PyObject *pyresult = \
            PyObject_CallFunction(context->ioReadCallback, "ii", context->ioParam, address);

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

    static void Z80IoWrite(void *ctx, ushort address, byte val)
    {
        /* Use the Z80 context to find the io read callback */
        Z80Context *context = (Z80Context *) ctx;

        /* if the callback is null or not callable return 0 */
        if (context->ioWriteCallback != NULL && PyCallable_Check(context->ioWriteCallback)) {
            PyObject *pyresult = \
                PyObject_CallFunction(context->ioWriteCallback, "iii", context->ioParam, address, val);

            if (pyresult) {
                Py_DECREF(pyresult);
            }
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

%typemap(in) byte {
    $1 = PyInt_AsLong($input);
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

/* Basic typedefs */
typedef unsigned short ushort;
typedef unsigned char byte;

/**
 * A Z80 register set.
 * An union is used since we want independent access to the high and low bytes of the 16-bit registers.
 */
typedef union
{
    /** Word registers. */
    struct
    {
        ushort AF, BC, DE, HL, IX, IY, SP;
    } wr;

    /** Byte registers. Note that SP can't be accesed partially. */
    struct
    {
        byte F, A, C, B, E, D, L, H, IXl, IXh, IYl, IYh;
    } br;
} Z80Regs;

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

    Z80DataIn   memRead;
    Z80DataOut  memWrite;
    int         memParam;

    Z80DataIn   ioRead;
    Z80DataOut  ioWrite;
    int         ioParam;

    byte        halted;
    unsigned    tstates;

    %immutable;
    /* Below are implementation details which may change without
     * warning; they should not be relied upon by any user of this
     * library.
     */

    /* If true, an NMI has been requested. */

    byte nmi_req;

    /* If true, a maskable interrupt has been requested. */

    byte int_req;

    /* If true, defer checking maskable interrupts for one
     * instruction.  This is used to keep an interrupt from happening
     * immediately after an IE instruction. */

    byte defer_int;

    /* When a maskable interrupt has been requested, the interrupt
     * vector.  For interrupt mode 1, it's the opcode to execute.  For
     * interrupt mode 2, it's the LSB of the interrupt vector address.
     * Not used for interrupt mode 0.
     */

    byte int_vector;

    /* If true, then execute the opcode in int_vector. */

    byte exec_int_vector;
    %mutable;

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

        /* Wrapper memeory handlers */
        z->memRead = &Z80MemoryRead;
        z->memWrite = &Z80MemoryWrite;
        z->ioRead = &Z80IoRead;
        z->ioWrite = &Z80IoWrite;

        z->memReadCallback = NULL;
        z->memWriteCallback = NULL;
        z->ioReadCallback = NULL;
        z->ioWriteCallback = NULL;
        z->memParam = 0;
        z->ioParam = 0;
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

    /* Write memory */
    void setMemWriteCallback(PyObject* callback) {

        /* Check to see if it is already set, an decref if it is */
        if ($self->memWriteCallback != NULL) {
            Py_DECREF($self->memWriteCallback);
        }

        Py_INCREF(callback);
        $self->memWriteCallback = callback;
    }

    PyObject* getMemWriteCallback() {
        return $self->memWriteCallback;
    }

    int writeMem(ushort address, byte val) {
        /* if the callback is null or not callable return 0 */
        if ($self->memWriteCallback == NULL || !PyCallable_Check($self->memWriteCallback)) {
            return 0;
        }

        PyObject *pyresult = \
            PyObject_CallFunction($self->memWriteCallback, "iii", $self->memParam, address, val);

        if (pyresult) {
            /* Return the result, converting from a python int */
            Py_DECREF(pyresult);
            return 1;
        } else {
            /* On error return 0 */
            return 0;
        }
    }

    /* ioRead ioory */
    void setIoReadCallback(PyObject* callback) {

        /* Check to see if it is already set, an decref if it is */
        if ($self->ioReadCallback != NULL) {
            Py_DECREF($self->ioReadCallback);
        }

        Py_INCREF(callback);
        $self->ioReadCallback = callback;
    }

    PyObject* getIoReadCallback() {
        return $self->ioReadCallback;
    }

    int readIo(ushort address, byte *result) {
        /* if the callback is null or not callable return 0 */
        if ($self->ioReadCallback == NULL || !PyCallable_Check($self->ioReadCallback)) {
            return 0;
        }

        PyObject *pyresult = \
            PyObject_CallFunction($self->ioReadCallback, "ii", $self->ioParam, address);

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

    /* ioWrite ioory */
    void setIoWriteCallback(PyObject* callback) {

        /* Check to see if it is already set, an decref if it is */
        if ($self->ioWriteCallback != NULL) {
            Py_DECREF($self->ioWriteCallback);
        }

        Py_INCREF(callback);
        $self->ioWriteCallback = callback;
    }

    PyObject* getIoWriteCallback() {
        return $self->ioWriteCallback;
    }

    int writeIo(ushort address, byte val) {
        /* if the callback is null or not callable return 0 */
        if ($self->ioWriteCallback == NULL || !PyCallable_Check($self->ioWriteCallback)) {
            return 0;
        }

        PyObject *pyresult = \
            PyObject_CallFunction($self->ioWriteCallback, "iii", $self->ioParam, address, val);

        if (pyresult) {
            /* Return the result, converting from a python int */
            Py_DECREF(pyresult);
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
        # memory callbacks
        __swig_getmethods__["memReadCallback"] = getMemReadCallback
        __swig_setmethods__["memReadCallback"] = setMemReadCallback
        if _newclass: memReadCallback = property(getMemReadCallback, setMemReadCallback)
        __swig_getmethods__["memWriteCallback"] = getMemWriteCallback
        __swig_setmethods__["memWriteCallback"] = setMemWriteCallback
        if _newclass: memWriteCallback = property(getMemWriteCallback, setMemWriteCallback)

        # io callbacks
        __swig_getmethods__["ioReadCallback"] = getIoReadCallback
        __swig_setmethods__["ioReadCallback"] = setIoReadCallback
        if _newclass: ioReadCallback = property(getIoReadCallback, setIoReadCallback)
        __swig_getmethods__["ioWriteCallback"] = getIoWriteCallback
        __swig_setmethods__["ioWriteCallback"] = setIoWriteCallback
        if _newclass: ioWriteCallback = property(getIoWriteCallback, setIoWriteCallback)
    %}

}
