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

import pyz80
import unittest

class TestSequenceFunctions(unittest.TestCase):

    def setUp(self):
        self.context = pyz80.Z80Context()

    def test_bad_callback(self):
        with self.assertRaises(TypeError):
            self.context.memReadCallback = 1

        with self.assertRaises(TypeError):
            self.context.memWriteCallback = 1

        with self.assertRaises(TypeError):
            self.context.ioReadCallback = 1

        with self.assertRaises(TypeError):
            self.context.ioWriteCallback = 1

    def test_good_callback(self):
        self.context.memReadCallback = lambda p, a: a
        self.context.memWriteCallback = lambda p, a, v: a
        self.context.ioReadCallback = lambda p, a: a
        self.context.ioWriteCallback = lambda p, a, v: a

if __name__ == '__main__':
    unittest.main()

