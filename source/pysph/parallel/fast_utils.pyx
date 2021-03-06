"""
Some utitlty functions written in cython.
"""
import numpy

from pysph.base.carray cimport LongArray

cpdef make_nd_array(list arrays=[]):
    """
    Makes a proper array of shape (len(a), len(arrays)), from the passed arrays.
    """
    cdef int na = len(arrays)
    cdef int a_size
    if na == 0:
        return None

    # make sure each array given in input is of same size.
    a_size = len(arrays[0])
    for i in range(na):
        if <int>len(arrays[0]) != a_size:
            return None
    
    a = numpy.zeros((a_size, na))
    
    for i in range(na):
        _a = arrays[i]
        for j from 0 <= j < a_size:
            a[j][i] = _a[j]

    return a


cpdef LongArray arange_long(long start, long stop=-1):
    """ Creates a LongArray working same as builtin range with upto 2 arguments
    both expected to be positive
    """
    
    cdef LongArray arange
    cdef long i = 0
    cdef long size = 0
    
    if stop == -1:
        arange = LongArray(start)
        for i in range(start):
            arange.data[i] = i
        return arange
    else:
        size = stop-start
        arange = LongArray(size)
        for i in range(size):
            arange.data[i] = start + i
        return arange
        
