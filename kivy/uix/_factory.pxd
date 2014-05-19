cdef struct Machine:
    char module
    object cls
    bint is_template
    tuple baseclasses
    char filename

cdef class FactoryBase(object):
    cdef dict classes
