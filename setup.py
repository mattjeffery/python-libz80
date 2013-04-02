#!/usr/bin/env python

"""
setup.py file for SWIG pyz80
"""
from setuptools import setup, Extension

__version__ = '0.1'
__author__ = 'Matt Jeffery <matt@clan.se>'


pyz80_module = Extension('_pyz80',
                           sources=['z80.c', 'libz80.i'],
                           define_macros=[('SWIG', None), ('SWIG_PYTHON', None)],
                           )

setup (name='pyz80',
       version=__version__,
       author=__author__,
       description="""Python wrapper for libz80""",
       ext_modules=[pyz80_module],
       py_modules=["pyz80"],
       )
