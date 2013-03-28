#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
#  pyz80_test.py
#
#  Copyright 2013 Matt Jeffery <matt@clan.se>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.

import sys
import pyz80
import array
import string
import logging

log = logging.getLogger(__name__)

# static context

class TestEmulator(object):
    def __init__(self):
        """
            Setup the test emualtor
        """
        self.context = pyz80.Z80Context()

        # Set up the memory callbacks
        log.debug("Setting the memory callback methods")
        self.context.memReadCallback = self._mem_read_callback
        self.context.memWriteCallback = self._mem_write_callback
        self.context.ioReadCallback = self._io_read_callback
        self.context.ioWriteCallback = self._io_write_callback

        # 64Kb of RAM
        self.initial_memory = array.array('c', ['\x00']*0x10000)
        self.memory = array.array('c', ['\x00']*0x10000)

        self.reset()

    def _mem_read_callback(self, param, address):
        """
            Memory read callback
        """
        log.debug("Reading memory: 0x{0:04x} = 0x{1:02x}".format(address, ord(self.memory[address])))
        return ord(self.memory[address])

    def _mem_write_callback(self, param, address, data):
        """
            Memory write callback
        """
        log.debug("Setting memory: {0:04x}={1:02x}".format(address, data))
        self.memory[address] = chr(data)

    def _io_read_callback(self, param, address):
        """
            io read callback
        """
        data = address >> 8
        sys.stdout.write("PR {0:04x} {1:02x}\n".format(address, data))
        return data

    def _io_write_callback(self, param, address, data):
        """
            io write callback
        """
        sys.stdout.write("PW {0:04x} {1:02x}\n".format(address, data))


    def fill_memory(self):
        """
            Set the memory to default values
        """
        log.debug("Resetting the memory")
        for  i in range(0, 0x10000, 4):
            self.memory[i] = chr(0xde)
            self.memory[i+1] = chr(0xad)
            self.memory[i+2] = chr(0xbe)
            self.memory[i+3] = chr(0xef)

    def reset(self):
        """
            Reset the state of the emulator
        """
        log.debug("Resetting the Z80 context")
        self.context.reset()
        self.fill_memory()

    def dump_z80_state(self):
        """
            Dump the state of the emulator's z80
        """
        self.context.dump_z80_state()

    def dump_memory_state(self, initial_memory):
        """
            Dump the emulators memory state
        """
        i = 0x00
        while i < 0x10000:
            # unchanged
            if(self.memory[i] == initial_memory[i]):
                i += 1
                continue

            sys.stdout.write("%04x " % i)

            while i < 0x10000 and self.memory[i] != initial_memory[i]:
                sys.stdout.write("%02x " % ord(self.memory[i]))
                i += 1

            sys.stdout.write("-1\n")

    def load_next_test(self, fileh):
        """
        00
        0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
        00 00 0 0 0 0     1
        0000 00 -1
        -1

        """
        # Read the test name from the file
        while True:
            test_name = fileh.next().strip()
            if len(test_name) > 0:
                break

        log.info("Loading test {0}".format(test_name))

        # Read the registers
        line = fileh.next()
        data = line.strip().split()

        (self.context.R1.wr.AF,
         self.context.R1.wr.BC,
         self.context.R1.wr.DE,
         self.context.R1.wr.HL,
         self.context.R2.wr.AF,
         self.context.R2.wr.BC,
         self.context.R2.wr.DE,
         self.context.R2.wr.HL,
         self.context.R1.wr.IX,
         self.context.R1.wr.IY,
         self.context.R1.wr.SP,
         self.context.PC) = \
            map(lambda x: int(x, base=16), data)

        line = fileh.next()
        data = line.strip().split()

        (self.context.I,
         self.context.R,
         self.context.IFF1,
         self.context.IFF2,
         self.context.IM,
         self.context.halted,
         end_tstates) = \
            map(lambda x: int(x, base=16), data) # "%x %x %u %u %u %d %d"

        while True:
            # for each line read the data encoded
            line = fileh.next().strip().split()
            data = map(lambda x: int(x, base=16), line)
            try:
                address = data[0]
            except IndexError:
                raise ValueError, "test:{0}: no address found".format(test_name, address)

            if address == -1:
                break

            # Read the data off the line
            for byte in data[1:]:
                if byte == -1:
                    break
                self.memory[address] = chr(byte)
                address += 1

        return test_name, end_tstates

    def run_next_test(self, fileh):
        self.reset()

        # read one test, the end_tstates is returned
        try:
            test_name, end_tstates = self.load_next_test(fileh)
        except StopIteration:
            return

        # Save the current memory state for comparison later
        initial_memory = self.memory[:0x10000]

        sys.stdout.write("{0}\n".format(test_name))

        log.info("Running test {0}, waiting for end_tstates={1}".format(test_name, end_tstates))
        while self.context.tstates < end_tstates:
            self.context.execute()

        self.dump_z80_state()
        self.dump_memory_state(initial_memory)
        sys.stdout.write("\n")

        return True

def main(filename="testfile"):
    # open test file
    emu = TestEmulator()

    with open(filename) as fileh:
        i = 0
        while emu.run_next_test(fileh):
            i += 1
            pass

if __name__ == '__main__':
    FORMAT = '%(asctime)-15s %(levelname)s %(message)s'
    logging.basicConfig(format=FORMAT, level=logging.DEBUG)

    test_file = "../fuse_tests/fuse_files/tests.in"

    main(test_file)

